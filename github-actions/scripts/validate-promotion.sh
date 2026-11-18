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
# Preparar a origem e transferir a tag que foi realmente lida dela.
(cd "$work"; bash "$root/github-actions/scripts/update_tag.sh" "$source_env" "$tag")
source_file="$work/apps/sample-api/overlays/$source_env/kustomization.yaml"
target_file="$work/apps/sample-api/overlays/$target_env/kustomization.yaml"
source_tag=$(awk '/^[[:space:]]*newTag:/ {gsub(/"/, "", $2); print $2}' "$source_file")
[[ "$source_tag" =~ ^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$ ]]
test "$source_tag" = "$tag"
source_name=$(awk '/^[[:space:]]*newName:/ {print $2}' "$source_file")
target_name=$(awk '/^[[:space:]]*newName:/ {print $2}' "$target_file")
test -n "$source_name" && test "$source_name" = "$target_name"
(cd "$work"; bash "$root/github-actions/scripts/update_tag.sh" "$target_env" "$source_tag")
test "$source_tag" = "$(awk '/^[[:space:]]*newTag:/ {gsub(/"/, "", $2); print $2}' "$target_file")"
grep -F "newTag: \"$tag\"" "$work/apps/sample-api/overlays/$target_env/kustomization.yaml"
kustomize build "$work/apps/sample-api/overlays/$target_env" > "$work/rendered.yaml"
kubeconform -strict -summary -ignore-missing-schemas "$work/rendered.yaml"
grep -F ":$tag" "$work/rendered.yaml"
test "$before" = "$(find apps/sample-api/overlays -type f -exec sha256sum {} + | sort)"
printf 'Simulação %s -> %s validada; checkout e ambientes preservados.\n' "$source_env" "$target_env"
