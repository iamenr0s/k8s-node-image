#!/usr/bin/env bash
# Build the k8s-node bootc image for the host architecture (rootful podman:
# bootc-image-builder and the boot tests read root's container storage).
# Usage: sudo scripts/build.sh [image-ref]     (default localhost/k8s-node:<minor>)
# Env:   BASE_IMAGE K8S_MINOR K8S_VERSION CRIO_MINOR CRIO_VERSION EXTRA_PACKAGES
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
K8S_MINOR="${K8S_MINOR:-v1.37}"
IMAGE="${1:-localhost/k8s-node:${K8S_MINOR#v}}"
args=()
for v in BASE_IMAGE K8S_MINOR K8S_VERSION CRIO_MINOR CRIO_VERSION EXTRA_PACKAGES; do
  [ -n "${!v:-}" ] && args+=(--build-arg "${v}=${!v}")
done
podman build --pull=newer "${args[@]}" --file "${ROOT}/Containerfile" --tag "${IMAGE}" "${ROOT}"
echo "built ${IMAGE}"
