# Karpenter (ArgoCD + Terraform)

## Objetivo

Integrar o Karpenter ao fluxo GitOps para:

- reduzir custo com preferencia por Spot e fallback automatico para On-Demand
- aumentar utilizacao dos nos com consolidacao de capacidade subutilizada
- manter configuracao declarativa de `NodePool` e `EC2NodeClass` via Argo CD

## O que esta provisionado

### Terraform (`terraform/modules/addons`)

- namespace `karpenter`
- IAM/IRSA do controller Karpenter
- role de nos: `KarpenterNodeRole-<cluster_name>`
- fila SQS de interrupcao Spot + eventos EventBridge
- Helm chart `karpenter-crd`
- Helm chart `karpenter`

### GitOps (`platform/karpenter`)

- `EC2NodeClass`:
  - AMI family `AL2023`
  - selectors por tag `karpenter.sh/discovery`
  - role de no Karpenter
- `NodePool`:
  - suporta `spot` e `on-demand` (spot-first com fallback)
  - consolidacao `WhenEmptyOrUnderutilized`
  - `consolidateAfter: 1m`
  - `expireAfter: 720h`

## Configuracao obrigatoria antes do apply

Atualize o nome do cluster usado no `EC2NodeClass`:

```bash
make configure-karpenter CLUSTER_NAME=gitops-dev
```

Esse valor precisa ser o mesmo `cluster_name` usado no Terraform do ambiente.

## Validacoes recomendadas

```bash
kubectl -n karpenter get pods
kubectl get ec2nodeclass
kubectl get nodepool
kubectl get nodeclaims
```

Para verificar se a preferencia por Spot esta sendo usada:

```bash
kubectl get nodes -L karpenter.sh/capacity-type,node.kubernetes.io/instance-type
```

## Ajustes de tuning (custo x resiliencia)

- `platform/karpenter/base/nodepool-cost-optimized.yaml`
  - ajuste `limits.cpu` para limitar crescimento maximo
  - ajuste `instance-category` para restringir familias
  - aumente `consolidateAfter` se houver churn excessivo
- `platform/karpenter/base/ec2-nodeclass.yaml`
  - fixe AMI por versao em vez de `al2023@latest` quando precisar de maior controle
