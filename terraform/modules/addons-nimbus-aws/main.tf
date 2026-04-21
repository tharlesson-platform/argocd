locals {
  oidc_provider_hostpath = replace(var.oidc_provider_url, "https://", "")
}

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
}

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
  }
}

resource "kubernetes_namespace" "external_secrets" {
  metadata {
    name = "external-secrets"
  }
}

resource "kubernetes_namespace" "ingress_nginx" {
  metadata {
    name = "ingress-nginx"
  }
}

resource "kubernetes_namespace" "argo_rollouts" {
  metadata {
    name = "argo-rollouts"
  }
}

data "aws_iam_policy_document" "external_secrets_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_hostpath}:sub"
      values = [
        "system:serviceaccount:${kubernetes_namespace.external_secrets.metadata[0].name}:external-secrets"
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_hostpath}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "external_secrets" {
  name               = "${var.cluster_name}-nimbus-external-secrets"
  assume_role_policy = data.aws_iam_policy_document.external_secrets_assume_role.json
  tags               = var.tags
}

resource "aws_iam_policy" "external_secrets" {
  name = "${var.cluster_name}-nimbus-external-secrets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecrets"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = ["kms:Decrypt"]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "external_secrets" {
  role       = aws_iam_role.external_secrets.name
  policy_arn = aws_iam_policy.external_secrets.arn
}

resource "helm_release" "ingress_nginx" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  namespace  = kubernetes_namespace.ingress_nginx.metadata[0].name
  version    = var.ingress_nginx_chart_version
}

resource "helm_release" "external_secrets" {
  name       = "external-secrets"
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  namespace  = kubernetes_namespace.external_secrets.metadata[0].name
  version    = var.external_secrets_chart_version

  values = [
    yamlencode({
      installCRDs = true
      serviceAccount = {
        create = true
        name   = "external-secrets"
        annotations = {
          "eks.amazonaws.com/role-arn" = aws_iam_role.external_secrets.arn
        }
      }
    })
  ]

  depends_on = [aws_iam_role_policy_attachment.external_secrets]
}

resource "kubernetes_manifest" "cluster_secret_store" {
  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ClusterSecretStore"
    metadata = {
      name = "platform-secrets"
    }
    spec = {
      provider = {
        aws = {
          service = "SecretsManager"
          region  = var.region
          auth = {
            jwt = {
              serviceAccountRef = {
                name      = "external-secrets"
                namespace = kubernetes_namespace.external_secrets.metadata[0].name
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.external_secrets]
}

resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  version    = var.kube_prometheus_stack_version

  values = [
    yamlencode({
      grafana = {
        adminPassword = "admin-change-me"
      }
      prometheus = {
        prometheusSpec = {
          serviceMonitorSelectorNilUsesHelmValues = false
          podMonitorSelectorNilUsesHelmValues     = false
          ruleSelectorNilUsesHelmValues           = false
        }
      }
    })
  ]
}

resource "helm_release" "argo_rollouts" {
  name       = "argo-rollouts"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-rollouts"
  namespace  = kubernetes_namespace.argo_rollouts.metadata[0].name
  version    = var.argo_rollouts_chart_version

  values = [
    yamlencode({
      dashboard = {
        enabled = true
      }
      controller = {
        metrics = {
          enabled = true
        }
      }
    })
  ]
}

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  version    = var.argocd_chart_version

  values = [
    yamlencode({
      crds = {
        install = true
      }
      global = {
        domain = "argocd.${var.domain_name}"
      }
      configs = {
        params = {
          "server.insecure" = true
        }
      }
      notifications = {
        enabled = true
      }
    })
  ]
}

resource "kubernetes_manifest" "argocd_root_app" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "root-app"
      namespace = kubernetes_namespace.argocd.metadata[0].name
      annotations = {
        "argocd.argoproj.io/sync-wave" = "-100"
      }
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.gitops_repo_url
        targetRevision = var.gitops_repo_revision
        path           = var.gitops_root_path
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = kubernetes_namespace.argocd.metadata[0].name
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = [
          "CreateNamespace=true",
          "ApplyOutOfSyncOnly=true"
        ]
      }
    }
  }

  depends_on = [
    helm_release.argocd,
    helm_release.argo_rollouts,
    helm_release.ingress_nginx,
    kubernetes_manifest.cluster_secret_store
  ]
}
