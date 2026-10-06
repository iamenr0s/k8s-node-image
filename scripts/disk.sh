#!/usr/bin/env bash
# Produce disk artifacts from a bootc image with bootc-image-builder.
# Usage: sudo scripts/disk.sh <qcow2|raw|anaconda-iso> <worker|controlplane> <image-ref> [out-dir]
# Env:   SSH_PUBKEY_FILE (default ./keys/k8sadmin_ed25519.pub)
#        TRACK_REF       registry ref installed hosts follow (default: <image-ref>)
#        BIB_IMAGE       bootc-image-builder image (pin by digest in CI)
set -euo pipefail
TYPE="${1:?type: qcow2|raw|anaconda-iso}"
ROLE="${2:?role: worker|controlplane}"
IMAGE="${3:?image ref}"
OUT="${4:-./output/${ROLE}-${TYPE}}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SSH_PUBKEY_FILE="${SSH_PUBKEY_FILE:-./keys/k8sadmin_ed25519.pub}"
TRACK_REF="${TRACK_REF:-${IMAGE}}"
BIB_IMAGE="${BIB_IMAGE:-quay.io/centos-bootc/bootc-image-builder:latest}"

case "${ROLE}" in worker|controlplane) ;; *) echo "bad role ${ROLE}" >&2; exit 2 ;; esac
pubkey="$(tr -d '\n' < "${SSH_PUBKEY_FILE}")"
case "${pubkey}" in ssh-ed25519\ *|ecdsa-sha2-*|sk-*|ssh-rsa\ *) ;; *) echo "not an SSH public key: ${SSH_PUBKEY_FILE}" >&2; exit 1 ;; esac

mkdir -p "${OUT}"
cfg="$(mktemp --suffix=.toml)"
trap 'rm -f "${cfg}"' EXIT
if [ "${TYPE}" = anaconda-iso ]; then
  src="${ROOT}/bib/iso.toml.in"
else
  src="${ROOT}/bib/qcow2-${ROLE}.toml"
fi
# '|' delimiter: keys and refs contain '/', never '|'
sed -e "s|@SSH_PUBKEY@|${pubkey}|g" -e "s|@DEFAULT_ROLE@|${ROLE}|g" -e "s|@TRACK_REF@|${TRACK_REF}|g" \
  "${src}" > "${cfg}"

# bootc-image-builder reads the image from root's storage (pull it first).
podman image exists "${IMAGE}" || podman pull "${IMAGE}"

podman run --rm --privileged --pull=newer \
  --security-opt label=type:unconfined_t \
  -v "${cfg}:/config.toml:ro" \
  -v "$(realpath "${OUT}"):/output" \
  -v /var/lib/containers/storage:/var/lib/containers/storage \
  "${BIB_IMAGE}" \
  --type "${TYPE}" --use-librepo=True --progress verbose \
  "${IMAGE}"

find "${OUT}" -type f \( -name '*.qcow2' -o -name '*.raw' -o -name '*.iso' \) -exec sha256sum {} + | tee "${OUT}/SHA256SUMS"
