# Guia de Bootstrap

## 1) Pré-requisitos

- Conta AWS com permissões para VPC/EKS/IAM/ECR/addons gerenciados por Helm
- `terraform >= 1.7`
- `kubectl`, `aws`, `kustomize`
- Zona DNS preparada para hosts no padrão `*.example.internal` (ou seu domínio)

## 2) Prepare variáveis

Para cada ambiente:

```bash
cp terraform/environments/dev/terraform.tfvars.example terraform/environments/dev/terraform.tfvars
```

Ajuste no mínimo:

- `region`
- `domain_name`
- `gitops_repo_url`
- CIDRs de subnets / lista de AZs
- `argocd/root-app/gitops-settings.yaml` (`repoURL` + `revision`)

Aplique os placeholders de manifests:

```bash
make configure-domain DOMAIN=platform.example.com
make configure-ecr ECR_IMAGE=123456789012.dkr.ecr.us-east-1.amazonaws.com/sample-api
make configure-karpenter CLUSTER_NAME=gitops-dev
```

## 3) Provisione infraestrutura + bootstrap do Argo CD

```bash
make terraform-apply ENV=dev
```

Terraform cria:

- VPC, subnets, EKS, node groups gerenciados
- repositórios ECR
- papéis IAM/IRSA
- addons base (Argo CD, Argo Rollouts, Prometheus stack, ESO, ALB controller, Kyverno)
- Karpenter (IRSA, fila de interrupcao Spot e controller via Helm)
- `root-app` inicial do Argo CD

## 4) Confirme handoff para GitOps

```bash
kubectl -n argocd get applications
kubectl -n argocd get app root-app -o yaml
```

Esperado:

- `root-app` em `Synced` e `Healthy`
- apps filhas criadas (`argocd-config`, modulos `platform-*`, workloads por ambiente)
- `root-app` sendo reconciliada a partir de `argocd/root-app/root-application.yaml` (self-managed)

## 5) Publique segredos obrigatórios no AWS Secrets Manager

```text
/gitops/sample-api/dev         (property: API_KEY)
/gitops/sample-api/stage       (property: API_KEY)
/gitops/sample-api/prod        (property: API_KEY)
/gitops/argocd/notifications   (property: SLACK_TOKEN)
```

## 6) Acesse endpoints

- Argo CD: `https://argocd.<domain_name>`
- Dashboard do Rollouts: `https://rollouts.<domain_name>`
- sample-api:
  - `https://sample-api-dev.<domain_name>`
  - `https://sample-api-stage.<domain_name>`
  - `https://sample-api.<domain_name>`

## 7) Valide saúde básica da plataforma

```bash
kubectl -n external-secrets get pods
kubectl -n monitoring get pods
kubectl -n argo-rollouts get pods
kubectl -n karpenter get pods
kubectl get nodepool
kubectl -n sample-api-dev get rollout sample-api
```
