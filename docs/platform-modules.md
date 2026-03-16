# Deploy modular de plataforma

## Objetivo

Permitir deploy independente por modulo de plataforma (ex.: somente Argo CD config, somente Karpenter, etc.).

## Aplicacoes Argo CD por modulo

- `argocd/applications/platform-namespaces-app.yaml`
  - app: `platform-namespaces`
  - path: `platform/namespaces/base`
- `argocd/applications/platform-ingress-app.yaml`
  - app: `platform-ingress`
  - path: `platform/ingress/overlays/shared`
- `argocd/applications/platform-external-secrets-app.yaml`
  - app: `platform-external-secrets`
  - path: `platform/external-secrets/overlays/shared`
- `argocd/applications/argocd-config-app.yaml`
  - app: `argocd-config`
  - path: `platform/argocd/overlays/shared`
- `argocd/applications/platform-monitoring-app.yaml`
  - app: `platform-monitoring`
  - path: `platform/monitoring/overlays/shared`
- `argocd/applications/platform-argo-rollouts-app.yaml`
  - app: `platform-argo-rollouts`
  - path: `platform/argo-rollouts/overlays/shared`
- `argocd/applications/platform-kyverno-policies-app.yaml`
  - app: `platform-kyverno-policies`
  - path: `platform/policies/kyverno/overlays/shared`
- `argocd/applications/platform-karpenter-app.yaml`
  - app: `platform-karpenter`
  - path: `platform/karpenter/overlays/shared`

## Como subir somente um modulo

Se voce nao estiver usando `root-app`, aplique antes o projeto da plataforma:

```bash
kubectl apply -n argocd -f argocd/projects/platform-project.yaml
```

Exemplo: somente Karpenter

```bash
kubectl apply -n argocd -f argocd/applications/platform-karpenter-app.yaml
```

Exemplo: somente configuracao do Argo CD

```bash
kubectl apply -n argocd -f argocd/applications/argocd-config-app.yaml
```

## Dependencias entre modulos

- `platform-namespaces`: base para todos os demais.
- `platform-ingress`: recomendado antes de `argocd-config` e `platform-argo-rollouts` (ingresses).
- `platform-external-secrets`: recomendado antes de `argocd-config` (ExternalSecret de notificacoes).
- `argocd-config`: depende de namespace `argocd` e funciona melhor com `platform-ingress` + `platform-external-secrets`.
- `platform-karpenter`: depende do namespace `karpenter` e dos prerequisitos IAM/Helm provisionados no Terraform.

## Como sincronizar somente um modulo

Se a aplicacao ja existir no Argo CD:

```bash
argocd app sync platform-karpenter
```

## Ordem recomendada entre modulos

1. `platform-namespaces`
2. `platform-ingress`
3. `platform-external-secrets`
4. `argocd-config`
5. `platform-monitoring`
6. `platform-argo-rollouts`
7. `platform-kyverno-policies`
8. `platform-karpenter`

A ordem acima ja esta refletida em `sync-wave` nos manifests das Applications.

## Observacao sobre o root-app

O `root-app` continua sendo o modo recomendado para bootstrap completo e reconcilia todos os modulos automaticamente.
