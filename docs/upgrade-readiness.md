# Upgrade Readiness

Este repositório pode exportar um bundle local para ser analisado pelo projeto
`kubernetes-upgrade-readiness-analyzer` sem depender de cluster ativo.

## O que entra no bundle

- `apps/sample-api/base`
- `apps/sample-api/overlays/stage`
- `platform/monitoring/base`
- `platform/karpenter/base`
- `eks-addons.json` de exemplo para simular a camada de addons EKS

## Gerando o bundle

```bash
./scripts/collect-upgrade-readiness-bundle.sh /tmp/argocd-upgrade-bundle
```

## Analisando com o outro repositório

```bash
kubernetes-upgrade-readiness-analyzer scan \
  --manifests-path /tmp/argocd-upgrade-bundle \
  --target-version 1.30 \
  --output-dir /tmp/argocd-upgrade-report
```

## Como usar isso na rotina

- validar upgrades antes de promover mudanças grandes na plataforma
- revisar `sample-api`, `monitoring` e `karpenter` com o mesmo checklist
- anexar o relatório em PRs ou change reviews de upgrade
