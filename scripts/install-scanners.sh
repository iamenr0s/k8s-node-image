#!/usr/bin/env bash
# Install pinned grype + trivy release binaries, verified against each
# release's checksums file. No curl | sh installers.
# Usage: scripts/install-scanners.sh [bin-dir]   (default /usr/local/bin; needs gh + GH_TOKEN)
set -euo pipefail

# Bumped by Renovate (see customManagers in renovate.json).
# renovate: datasource=github-releases depName=anchore/grype
GRYPE_VERSION=0.115.0
# renovate: datasource=github-releases depName=aquasecurity/trivy
TRIVY_VERSION=0.72.0
BIN="${1:-/usr/local/bin}"

case "$(uname -m)" in
  x86_64)  grype_arch=linux_amd64; trivy_arch=Linux-64bit ;;
  aarch64) grype_arch=linux_arm64; trivy_arch=Linux-ARM64 ;;
  *) echo "unsupported arch: $(uname -m)" >&2; exit 1 ;;
esac

work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT
cd "${work}"

gh release download "v${GRYPE_VERSION}" -R anchore/grype \
  -p "grype_${GRYPE_VERSION}_${grype_arch}.tar.gz" -p "grype_${GRYPE_VERSION}_checksums.txt"
gh release download "v${TRIVY_VERSION}" -R aquasecurity/trivy \
  -p "trivy_${TRIVY_VERSION}_${trivy_arch}.tar.gz" -p "trivy_${TRIVY_VERSION}_checksums.txt"

cat ./*_checksums.txt | sha256sum --ignore-missing --strict -c -
tar xzf "grype_${GRYPE_VERSION}_${grype_arch}.tar.gz" grype
tar xzf "trivy_${TRIVY_VERSION}_${trivy_arch}.tar.gz" trivy
install -m 0755 grype trivy "${BIN}/"
"${BIN}/grype" version | head -2
"${BIN}/trivy" --version | head -1
