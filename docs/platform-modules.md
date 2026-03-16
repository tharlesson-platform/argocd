# Deploy modular de plataforma

## Objetivo

Permitir deploy independente por modulo (ex.: so Karpenter, so Argo CD config).

## Aplicacoes Argo CD por modulo

- `platform-namespaces` -> `argocd/applications/platform-namespaces-app.yaml`
- `platform-ingress` -> `argocd/applications/platform-ingress-app.yaml`
- `platform-external-secrets` -> `argocd/applications/platform-external-secrets-app.yaml`
- `argocd-config` -> `argocd/applications/argocd-config-app.yaml`
- `platform-monitoring` -> `argocd/applications/platform-monitoring-app.yaml`
- `platform-argo-rollouts` -> `argocd/applications/platform-argo-rollouts-app.yaml`
- `platform-kyverno-policies` -> `argocd/applications/platform-kyverno-policies-app.yaml`
- `platform-karpenter` -> `argocd/applications/platform-karpenter-app.yaml`

## Como subir somente um modulo

Se estiver usando modo standalone (sem root-app), aplique primeiro o projeto:

```bash
kubectl apply -n argocd -f argocd/projects/platform-project.yaml
```

Exemplo so Karpenter:

```bash
kubectl apply -n argocd -f argocd/applications/platform-karpenter-app.yaml
```

Exemplo so Argo CD config:

```bash
kubectl apply -n argocd -f argocd/applications/argocd-config-app.yaml
```

## Ordem recomendada

1. `platform-namespaces`
2. `platform-ingress`
3. `platform-external-secrets`
4. `argocd-config`
5. `platform-monitoring`
6. `platform-argo-rollouts`
7. `platform-kyverno-policies`
8. `platform-karpenter`
