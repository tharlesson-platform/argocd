#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <cluster-name>"
  echo "example: $0 gitops-dev"
  exit 1
fi

CLUSTER_NAME="$1"
NODECLASS_FILE="platform/karpenter/base/ec2-nodeclass.yaml"

set_value() {
  local file="$1"
  local pattern="$2"
  local replacement="$3"
  sed -i.bak -E "s#${pattern}#${replacement}#g" "$file"
  rm -f "${file}.bak"
}

set_value "${NODECLASS_FILE}" "role:[[:space:]]*KarpenterNodeRole-[^[:space:]]+" "role: KarpenterNodeRole-${CLUSTER_NAME}"
set_value "${NODECLASS_FILE}" "karpenter\\.sh/discovery:[[:space:]]*[^[:space:]]+" "karpenter.sh/discovery: ${CLUSTER_NAME}"

echo "Updated Karpenter EC2NodeClass with cluster name: ${CLUSTER_NAME}"
