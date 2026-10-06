#!/usr/bin/env bash
# Boot a disk image (as a throwaway overlay) under QEMU/UEFI with SSH on localhost.
# Usage: scripts/qemu-run.sh <disk.qcow2> [seed.iso]
# Env:   ARCH (x86_64|aarch64, default host), SSH_PORT (2222), MEM (4096), CPUS (2),
#        OVMF_CODE / OVMF_VARS to override firmware paths, SERIAL_LOG (default stdio)
set -euo pipefail
DISK="${1:?disk image}"; SEED="${2:-}"
ARCH="${ARCH:-$(uname -m)}"; SSH_PORT="${SSH_PORT:-2222}"; MEM="${MEM:-4096}"; CPUS="${CPUS:-2}"
work="${WORK:-$(mktemp -d)}"
firstfile() { for f in "$@"; do [ -f "${f}" ] && { echo "${f}"; return; }; done; return 1; }

if [ "${ARCH}" = x86_64 ]; then
  code="${OVMF_CODE:-$(firstfile /usr/share/edk2/ovmf/OVMF_CODE.fd /usr/share/OVMF/OVMF_CODE_4M.fd /usr/share/OVMF/OVMF_CODE.fd)}"
  vars="${OVMF_VARS:-$(firstfile /usr/share/edk2/ovmf/OVMF_VARS.fd /usr/share/OVMF/OVMF_VARS_4M.fd /usr/share/OVMF/OVMF_VARS.fd)}"
  qemu=(qemu-system-x86_64 -machine q35 -cpu host)
else
  code="${OVMF_CODE:-$(firstfile /usr/share/edk2/aarch64/QEMU_EFI-pflash.raw /usr/share/AAVMF/AAVMF_CODE.fd)}"
  vars="${OVMF_VARS:-$(firstfile /usr/share/edk2/aarch64/vars-template-pflash.raw /usr/share/AAVMF/AAVMF_VARS.fd)}"
  qemu=(qemu-system-aarch64 -machine virt -cpu host)
fi
accel=(-accel kvm)
if [ ! -w /dev/kvm ]; then
  echo "no /dev/kvm: using TCG (slow)" >&2
  accel=(-accel tcg); qemu[4]=max
fi

cp "${vars}" "${work}/vars.fd"
qemu-img create -q -f qcow2 -F qcow2 -b "$(realpath "${DISK}")" "${work}/overlay.qcow2"
seed=()
[ -n "${SEED}" ] && seed=(-drive "file=${SEED},if=virtio,media=cdrom,readonly=on")

exec "${qemu[@]}" "${accel[@]}" -smp "${CPUS}" -m "${MEM}" \
  -drive "if=pflash,format=raw,readonly=on,file=${code}" \
  -drive "if=pflash,format=raw,file=${work}/vars.fd" \
  -drive "file=${work}/overlay.qcow2,if=virtio,format=qcow2" \
  "${seed[@]}" \
  -netdev "user,id=n0,hostfwd=tcp:127.0.0.1:${SSH_PORT}-:22" -device virtio-net-pci,netdev=n0 \
  -display none -serial "${SERIAL_LOG:+file:}${SERIAL_LOG:-mon:stdio}"
