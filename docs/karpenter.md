# Karpenter (ArgoCD + Kustomize parametrizado)

## Objetivo

Configurar autoscaling de nós com foco em custo e eficiência:

- preferencia por Spot com fallback para On-Demand
- consolidação de nós subutilizados
- configuração declarativa via Argo CD

## Onde está a configuração

- base:
  - `platform/karpenter/base/ec2-nodeclass.yaml`
  - `platform/karpenter/base/nodepool-cost-optimized.yaml`
- overlay compartilhado:
  - `platform/karpenter/overlays/shared/kustomization.yaml`
  - `platform/karpenter/overlays/shared/karpenter-settings.env`

## Como funciona a parametrização do EC2NodeClass

O `EC2NodeClass` não tem valores hardcoded de cluster no base.

O overlay usa `replacements` do Kustomize para injetar:

- `CLUSTER_NAME` em:
  - `spec.subnetSelectorTerms[*].tags["karpenter.sh/discovery"]`
  - `spec.securityGroupSelectorTerms[*].tags["karpenter.sh/discovery"]`
- `NODE_ROLE` em:
  - `spec.role`

Fonte dos parâmetros:

- arquivo `platform/karpenter/overlays/shared/karpenter-settings.env`

## Comando para configurar

```bash
make configure-karpenter CLUSTER_NAME=gitops-dev
```

Esse comando atualiza:

- `CLUSTER_NAME=gitops-dev`
- `NODE_ROLE=KarpenterNodeRole-gitops-dev`

## Validação

```bash
kubectl -n karpenter get pods
kubectl get ec2nodeclass
kubectl get nodepool
kubectl get nodeclaims
kubectl get nodes -L karpenter.sh/capacity-type,node.kubernetes.io/instance-type
```
