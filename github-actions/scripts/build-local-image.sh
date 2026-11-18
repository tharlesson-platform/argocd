#!/usr/bin/env bash
# Registry exclusivamente em loopback, descartável com a VM de CI.
set -euo pipefail
root=$(git rev-parse --show-toplevel); cd "$root"
sha=${SOURCE_SHA:?}
[[ "$sha" =~ ^[a-f0-9]{40}$ ]]
test "$(git rev-parse HEAD)" = "$sha"
test "$(podman info --format '{{.Host.Security.Rootless}}')" = true
test "$(uname -m)" = aarch64
for name in AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_WEB_IDENTITY_TOKEN_FILE; do
  test -z "${!name:-}"
done
work=$(mktemp -d "${RUNNER_TEMP:?}/argocd-local-image.XXXXXXXX")
suffix=${work##*.}; registry=argocd-registry-$suffix; api=argocd-api-$suffix
cleanup() {
  result=$?
  trap - EXIT
  for name in "$api" "$registry"; do
    if podman container exists "$name"; then
      podman logs "$name" || true
      podman rm -f "$name" || result=1
    fi
  done
  # A VM será removida pelo controlador; o recibo fica no log do job.
  exit "$result"
}
trap cleanup EXIT
mkdir "$work/registry"
podman run -d --name "$registry" --read-only --cap-drop=ALL --security-opt=no-new-privileges \
  --tmpfs /tmp -v "$work/registry:/var/lib/registry:Z" -p 127.0.0.1::5000 \
  docker.io/library/registry@sha256:82f6ff4a7f982960c8aa51617fea3aabc485df6e55cce80d22deb1de36f1bc3c
address=$(podman port "$registry" 5000/tcp)
[[ "$address" =~ ^127\.0\.0\.1:[0-9]+$ ]]
for attempt in {1..30}; do
  if curl --fail --silent --show-error --max-time 2 "http://$address/v2/"; then break; fi
  test "$attempt" -lt 30
  sleep 1
done
image=localhost/sample-api-ci:sha-$sha
podman build --platform linux/arm64 --format oci --label org.opencontainers.image.revision="$sha" -t "$image" apps/sample-api/app
podman push --tls-verify=false --digestfile "$work/digest" "$image" "docker://$address/sample-api:sha-$sha"
digest=$(cat "$work/digest"); [[ "$digest" =~ ^sha256:[a-f0-9]{64}$ ]]
reference=$address/sample-api@$digest
# Excluir a imagem construída impede falso sucesso baseado apenas no cache local.
podman rmi "$image"
podman pull --tls-verify=false "$reference"
test "$(podman image inspect --format '{{.Digest}}' "$reference")" = "$digest"
test "$(podman image inspect --format '{{.Architecture}}' "$reference")" = arm64
podman save --format oci-archive -o "$work/image.oci.tar" "$reference"
curl --fail --location --proto '=https' --tlsv1.2 --retry 2 --max-time 180 \
  https://github.com/aquasecurity/trivy/releases/download/v0.76.2/trivy_0.76.2_Linux-ARM64.tar.gz -o "$work/trivy.tar.gz"
printf '%s  %s\n' ab9d51f86e6a5fb936f605faff6b593ac51bc378fff4d3e8b9d58358b9c367c3 "$work/trivy.tar.gz" | sha256sum --check --strict
tar -xzf "$work/trivy.tar.gz" -C "$work" trivy
TRIVY_CACHE_DIR="$work/trivy-cache" "$work/trivy" image --input "$work/image.oci.tar" \
  --scanners vuln --pkg-types os,library --ignorefile /dev/null --exit-code 1 \
  --list-all-pkgs --format json --output "$work/trivy.json"
python3 - "$work/trivy.json" <<'SCAN'
import json, sys
report = json.load(open(sys.argv[1]))
results = report.get("Results", [])
assert report["Metadata"]["OS"]["Family"] == "wolfi"
assert any(r.get("Type") == "wolfi" and r.get("Packages") for r in results)
assert any(r.get("Type") == "python-pkg" and r.get("Packages") for r in results)
assert not any(r.get("Vulnerabilities") for r in results)
print("Inventários OS/Python presentes; zero vulnerabilidades conhecidas, sem ignores.")
SCAN
podman run -d --name "$api" --pull=never --read-only --cap-drop=ALL \
  --security-opt=no-new-privileges --tmpfs /tmp:rw,noexec,nosuid,size=16m \
  -e APP_VERSION="$sha" -e FAILURE_RATE=0 -p 127.0.0.1::8080 "$reference"
api_address=$(podman port "$api" 8080/tcp); [[ "$api_address" =~ ^127\.0\.0\.1:[0-9]+$ ]]
for attempt in {1..30}; do
  if curl --fail --silent --show-error --max-time 2 "http://$api_address/ready"; then break; fi
  test "$attempt" -lt 30
  sleep 1
done
python3 github-actions/scripts/local-smoke.py --url "http://$api_address" --version "$sha"
test "$(podman exec "$api" id -u)" = 10001
sha256sum "$work/image.oci.tar" "$work/trivy.json"
printf 'RECIBO_LOCAL sha=%s digest=%s arquitetura=arm64 registry=%s scanner=0 deploy=false retencao=VM-descartavel\n' "$sha" "$digest" "$address"
