#!/usr/bin/env bash
set -euo pipefail
test "$(uname -s):$(uname -m)" = Linux:aarch64
directory=$(mktemp -d "${RUNNER_TEMP:?}/argocd-tools.XXXXXXXX")
fetch() {
  curl --fail --location --proto '=https' --tlsv1.2 --retry 2 --max-time 180 "$1" -o "$directory/tool.tar.gz"
  printf '%s  %s\n' "$2" "$directory/tool.tar.gz" | sha256sum --check --strict
  tar -xzf "$directory/tool.tar.gz" -C "$directory" "$3"
  chmod 0755 "$directory/$3"
}
fetch https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv5.4.3/kustomize_v5.4.3_linux_arm64.tar.gz 1b515578b0af12c15d9856720066ce2fe66756d63785b2cbccaf2885beb2381c kustomize
fetch https://github.com/yannh/kubeconform/releases/download/v0.6.7/kubeconform-linux-arm64.tar.gz dc82f79bb03c5479b1ae5fd4af221e4b5a3111f62bf01a2795d9c5c20fa96644 kubeconform
test "$("$directory/kustomize" version)" = v5.4.3
test "$("$directory/kubeconform" -v)" = v0.6.7
printf '%s\n' "$directory" >> "${GITHUB_PATH:?}"
