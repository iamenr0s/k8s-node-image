#!/usr/bin/env bash
# Scan an image with grype and trivy. Fails on fixable High/Critical.
# Usage: scan.sh <oci-layout-dir | registry-ref>
#   oci-layout-dir: from `podman save --format oci-dir -o <dir> <image>`
#   (bootc images are built with rootful podman, which neither scanner can read directly)
set -euo pipefail
TARGET="${1:?oci layout dir or image ref required}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [ -d "${TARGET}" ]; then
  GRYPE_SRC="oci-dir:${TARGET}"
  TRIVY_SRC=(--input "${TARGET}")
else
  GRYPE_SRC="registry:${TARGET}"
  TRIVY_SRC=("${TARGET}")
fi

echo "==> grype"
grype "${GRYPE_SRC}" \
  --config "${ROOT}/policies/grype.yaml" \
  --fail-on high \
  --only-fixed

echo "==> trivy"
trivy image \
  --config "${ROOT}/policies/trivy.yaml" \
  --severity HIGH,CRITICAL \
  --ignore-unfixed \
  --pkg-types os \
  --exit-code 1 \
  --scanners vuln,secret \
  "${TRIVY_SRC[@]}"

echo "==> scan passed: no fixable HIGH/CRITICAL vulnerabilities"
