#!/usr/bin/env bash
# Install a cosign release binary, verified against the release checksums
# (same approach as bootc-images' install-scanners.sh: no curl | sh).
# Usage: scripts/install-cosign.sh [bin-dir]    (needs gh + GH_TOKEN)
set -euo pipefail
# renovate: datasource=github-releases depName=sigstore/cosign
COSIGN_VERSION="${COSIGN_VERSION:-3.1.3}"
BIN="${1:-/usr/local/bin}"
if [ -z "${COSIGN_VERSION}" ]; then
  COSIGN_VERSION="$(gh release view -R sigstore/cosign --json tagName -q .tagName)"
  COSIGN_VERSION="${COSIGN_VERSION#v}"
  echo "warning: COSIGN_VERSION not pinned; using latest v${COSIGN_VERSION}" >&2
fi
case "$(uname -m)" in x86_64) a=amd64 ;; aarch64) a=arm64 ;; *) echo "unsupported arch" >&2; exit 1 ;; esac
work="$(mktemp -d)"; trap 'rm -rf "${work}"' EXIT; cd "${work}"
gh release download "v${COSIGN_VERSION}" -R sigstore/cosign -p "cosign-linux-${a}" -p cosign_checksums.txt
sha256sum --ignore-missing --strict -c cosign_checksums.txt
install -m 0755 "cosign-linux-${a}" "${BIN}/cosign"
"${BIN}/cosign" version | head -3
