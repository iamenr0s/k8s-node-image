#!/usr/bin/env bash
# End-to-end test of a qcow2: boot with a throwaway cloud-init user, prove
# key-only SSH, run the node checks, optionally `kubeadm init` a 1-node cluster.
# Usage: sudo scripts/vm-test.sh <disk.qcow2>
# Env:   EXPECT_K8S (e.g. 1.37.1)  ROLE (worker|controlplane)  KUBEADM_SMOKE=1  TIMEOUT (600)  ARCH  SSH_PORT
set -euo pipefail
DISK="${1:?disk.qcow2}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TIMEOUT="${TIMEOUT:-600}"; SSH_PORT="${SSH_PORT:-2222}"
work="$(mktemp -d)"; qpid=""
trap '[ -n "${qpid}" ] && kill "${qpid}" 2>/dev/null; wait 2>/dev/null; rm -rf "${work}"' EXIT

ssh-keygen -q -t ed25519 -N '' -C vm-test -f "${work}/id"
"${ROOT}/scripts/seed.sh" "${work}/id.pub" vm-test "${work}/seed.iso" citest
WORK="${work}" SERIAL_LOG="${work}/serial.log" SSH_PORT="${SSH_PORT}" \
  "${ROOT}/scripts/qemu-run.sh" "${DISK}" "${work}/seed.iso" &
qpid=$!

ssh_opts=(-p "${SSH_PORT}" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
          -o ConnectTimeout=5 -o LogLevel=ERROR)
vm() { ssh "${ssh_opts[@]}" -i "${work}/id" -o BatchMode=yes citest@127.0.0.1 "$@"; }

for ((t = 0; t < TIMEOUT; t += 5)); do
  vm true 2>/dev/null && break
  kill -0 "${qpid}" 2>/dev/null || { tail -50 "${work}/serial.log"; echo "VM exited" >&2; exit 1; }
  sleep 5
done
vm true || { tail -80 "${work}/serial.log" >&2; echo "no SSH within ${TIMEOUT}s" >&2; exit 1; }
echo "SSH up after ~${t}s"

# Password authentication must be refused by the server, before any prompt.
out="$(ssh "${ssh_opts[@]}" -o BatchMode=yes -o PubkeyAuthentication=no \
        -o PreferredAuthentications=password,keyboard-interactive citest@127.0.0.1 true 2>&1 || true)"
if grep -q 'Permission denied (publickey)' <<<"${out}"; then
  echo "PASS password/keyboard-interactive auth refused"
else
  echo "FAIL password auth not refused: ${out}"; exit 1
fi

vm "sudo EXPECT_K8S='${EXPECT_K8S:-}' ROLE='${ROLE:-}' bash -s" < "${ROOT}/scripts/validate-node.sh"

if [ "${KUBEADM_SMOKE:-0}" = 1 ]; then
  echo "==> kubeadm init smoke test"
  vm "sudo kubeadm init --pod-network-cidr 10.244.0.0/16 --ignore-preflight-errors=NumCPU,Mem >/tmp/init.log 2>&1 || { sudo tail -50 /tmp/init.log; exit 1; }"
  vm "sudo kubectl --kubeconfig /etc/kubernetes/admin.conf get --raw /readyz?verbose | tail -3"
  vm "sudo kubectl --kubeconfig /etc/kubernetes/admin.conf get nodes -o wide"
  vm "sudo crictl ps --name 'etcd|kube-apiserver' -q | wc -l | grep -qx 2" && echo "PASS control plane running"
fi
vm "sudo systemctl poweroff" || true
echo "vm-test: all checks passed"
