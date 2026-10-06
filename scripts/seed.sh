#!/usr/bin/env bash
# Build a cloud-init NoCloud seed ISO (volume label "cidata").
# Usage: scripts/seed.sh <pubkey-file> <hostname> <out.iso> [user]
set -euo pipefail
PUB="${1:?pubkey file}"; HOST="${2:?hostname}"; OUT="${3:?out iso}"; USER_NAME="${4:-k8sadmin}"
work="$(mktemp -d)"; trap 'rm -rf "${work}"' EXIT
cat > "${work}/user-data" <<UD
#cloud-config
users:
  - name: ${USER_NAME}
    groups: [wheel]
    lock_passwd: true
    shell: /bin/bash
    ssh_authorized_keys:
      - $(tr -d '\n' < "${PUB}")
ssh_pwauth: false
disable_root: true
UD
printf 'instance-id: %s\nlocal-hostname: %s\n' "${HOST}" "${HOST}" > "${work}/meta-data"
xorriso -as mkisofs -quiet -output "${OUT}" -volid cidata -joliet -rock \
  "${work}/user-data" "${work}/meta-data"
echo "seed: ${OUT}"
