#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <cluster-name>"
  echo "example: $0 gitops-dev"
  exit 1
fi

CLUSTER_NAME="$1"
SETTINGS_FILE="platform/karpenter/overlays/shared/karpenter-settings.env"

if [[ ! -f "${SETTINGS_FILE}" ]]; then
  echo "settings file not found: ${SETTINGS_FILE}"
  exit 1
fi

set_value() {
  local file="$1"
  local pattern="$2"
  local replacement="$3"
  sed -i.bak -E "s#${pattern}#${replacement}#g" "$file"
  rm -f "${file}.bak"
}

set_value "${SETTINGS_FILE}" "^CLUSTER_NAME=.*$" "CLUSTER_NAME=${CLUSTER_NAME}"
set_value "${SETTINGS_FILE}" "^NODE_ROLE=.*$" "NODE_ROLE=KarpenterNodeRole-${CLUSTER_NAME}"

echo "Updated ${SETTINGS_FILE} with cluster name: ${CLUSTER_NAME}"
