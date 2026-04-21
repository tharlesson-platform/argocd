#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <output-dir>"
  exit 1
fi

OUT_DIR="$1"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

rm -rf "${OUT_DIR}"
mkdir -p "${OUT_DIR}/sample-api-base"
mkdir -p "${OUT_DIR}/sample-api-stage"
mkdir -p "${OUT_DIR}/platform-monitoring"
mkdir -p "${OUT_DIR}/platform-karpenter"

cp -R "${ROOT_DIR}/apps/sample-api/base/." "${OUT_DIR}/sample-api-base/"
cp -R "${ROOT_DIR}/apps/sample-api/overlays/stage/." "${OUT_DIR}/sample-api-stage/"
cp -R "${ROOT_DIR}/platform/monitoring/base/." "${OUT_DIR}/platform-monitoring/"
cp -R "${ROOT_DIR}/platform/karpenter/base/." "${OUT_DIR}/platform-karpenter/"
cp "${ROOT_DIR}/examples/upgrade-readiness/eks-addons.example.json" "${OUT_DIR}/eks-addons.json"

cat > "${OUT_DIR}/README.md" <<'EOF'
# Upgrade readiness bundle

Bundle gerado a partir de manifests reais deste repositório para uso no `kubernetes-upgrade-readiness-analyzer`.

Exemplo de uso:

```bash
kubernetes-upgrade-readiness-analyzer scan --manifests-path <bundle-dir> --target-version 1.30
```
EOF

echo "bundle_ready=${OUT_DIR}"
