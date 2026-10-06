#!/usr/bin/env bash
# Unattended install from the ISO onto a blank 256 GiB (sparse) disk, then boot
# the installed system and wait for a login prompt with no failed units.
# Usage: sudo scripts/iso-test.sh <install.iso>     (x86_64 + KVM)
set -euo pipefail
ISO="${1:?install.iso}"; TIMEOUT="${TIMEOUT:-2400}"
firstfile() { for f in "$@"; do [ -f "${f}" ] && { echo "${f}"; return; }; done; return 1; }
code="${OVMF_CODE:-$(firstfile /usr/share/edk2/ovmf/OVMF_CODE.fd /usr/share/OVMF/OVMF_CODE_4M.fd)}"
vars="${OVMF_VARS:-$(firstfile /usr/share/edk2/ovmf/OVMF_VARS.fd /usr/share/OVMF/OVMF_VARS_4M.fd)}"
work="$(mktemp -d)"; trap 'rm -rf "${work}"' EXIT
cp "${vars}" "${work}/vars.fd"
qemu-img create -q -f qcow2 "${work}/disk.qcow2" 256G
# shellcheck disable=SC2054  # commas are QEMU option syntax
common=(qemu-system-x86_64 -machine q35 -accel kvm -cpu host -smp 2 -m 4096
  -drive "if=pflash,format=raw,readonly=on,file=${code}"
  -drive "if=pflash,format=raw,file=${work}/vars.fd"
  -drive "file=${work}/disk.qcow2,if=virtio,format=qcow2"
  -netdev user,id=n0 -device virtio-net-pci,netdev=n0 -display none)

echo "==> installing (QEMU exits when Anaconda reboots)"
timeout "${TIMEOUT}" "${common[@]}" -cdrom "${ISO}" -boot once=d -no-reboot \
  -serial "file:${work}/install.log" || { tail -60 "${work}/install.log" >&2; exit 1; }

echo "==> first boot from disk"
"${common[@]}" -serial "file:${work}/boot.log" & qpid=$!
for ((t = 0; t < 600; t += 5)); do
  grep -q '\[FAILED\]' "${work}/boot.log" 2>/dev/null && { grep '\[FAILED\]' "${work}/boot.log" >&2; kill "${qpid}"; exit 1; }
  grep -q 'login:' "${work}/boot.log" 2>/dev/null && { echo "iso-test: installed system reached login after ~${t}s"; kill "${qpid}"; exit 0; }
  sleep 5
done
kill "${qpid}"; tail -60 "${work}/boot.log" >&2; exit 1
