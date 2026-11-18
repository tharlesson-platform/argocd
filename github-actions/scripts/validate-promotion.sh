#!/usr/bin/env bash
# Simulação real em cópia descartável; não executa kubectl, Git push ou APIs.
set -euo pipefail
source_env=${1:?}; target_env=${2:?}; tag=${3:?}
case "$source_env:$target_env" in dev:stage|stage:prod) ;; *) echo 'Transição inválida' >&2; exit 1 ;; esac
[[ "$tag" =~ ^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$ ]]
root=$(git rev-parse --show-toplevel)
cd "$root"
before=$(find apps/sample-api/overlays -type f -exec sha256sum {} + | sort)
work=$(mktemp -d "${RUNNER_TEMP:-/tmp}/argocd-promotion.XXXXXXXX")
trap 'rm -rf "$work"' EXIT
cp -a apps "$work/apps"
(cd "$work"; bash "$root/github-actions/scripts/update_tag.sh" "$target_env" "$tag")
grep -F "newTag: \"$tag\"" "$work/apps/sample-api/overlays/$target_env/kustomization.yaml"
kustomize build "$work/apps/sample-api/overlays/$target_env" > "$work/rendered.yaml"
kubeconform -strict -summary -ignore-missing-schemas "$work/rendered.yaml"
grep -F ":$tag" "$work/rendered.yaml"
test "$before" = "$(find apps/sample-api/overlays -type f -exec sha256sum {} + | sort)"
printf 'Simulação %s -> %s validada; checkout e ambientes preservados.\n' "$source_env" "$target_env"
