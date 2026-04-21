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
          "azure.workload.identity/client-id" = var.external_secrets_identity_client_id
        }
        labels = {
          "azure.workload.identity/use" = "true"
        }
      }
      podLabels = {
        "azure.workload.identity/use" = "true"
      }
    })
  ]
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
        azurekv = {
          authType = "WorkloadIdentity"
          tenantId = var.tenant_id
          vaultUrl = var.key_vault_url
          serviceAccountRef = {
            name      = "external-secrets"
            namespace = kubernetes_namespace.external_secrets.metadata[0].name
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
