#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2329,SC2317  # sh -c bodies expand on the node; sshd_is is called via check
# Node conformance checks. Run as root ON the node:
#   sudo EXPECT_K8S=1.37.1 ROLE=worker|controlplane bash validate-node.sh
set -uo pipefail
fail=0
check() { local name="$1"; shift
  if "$@" >/dev/null 2>&1; then echo "PASS ${name}"; else echo "FAIL ${name}"; fail=1; fi; }
sshd_is() { sshd -T 2>/dev/null | grep -qix "$1 $2"; }

echo "== OS"
check "bootc reports a booted deployment" bootc status --booted
check "/usr is read-only"                 sh -c '! touch /usr/.rw-test'
check "SELinux enforcing"                 test "$(getenforce)" = Enforcing
check "no failed units"                   sh -c '[ -z "$(systemctl --failed --no-legend --plain)" ]'
check "no swap"                           sh -c '[ -z "$(swapon --noheadings)" ]'
check "auditd active"                     systemctl is-active --quiet auditd
check "chronyd active"                    systemctl is-active --quiet chronyd
check "bootc auto-reboot timer disabled"  sh -c '! systemctl is-enabled --quiet bootc-fetch-apply-updates.timer'
check "staged-update timer enabled"       systemctl is-enabled --quiet k8s-node-update.timer

echo "== SSH"
check "PasswordAuthentication no"         sshd_is passwordauthentication no
check "PermitRootLogin no"                sshd_is permitrootlogin no
check "KbdInteractiveAuthentication no"   sshd_is kbdinteractiveauthentication no
check "AuthenticationMethods publickey"   sshd_is authenticationmethods publickey
check "root password locked"              sh -c 'passwd -S root 2>/dev/null | grep -qE " (L|LK) " || grep -q "^root:[!*]" /etc/shadow'

echo "== Kubernetes prerequisites"
check "br_netfilter loaded"               test -d /sys/module/br_netfilter
check "ip_forward=1"                      test "$(sysctl -n net.ipv4.ip_forward)" = 1
check "bridge-nf-call-iptables=1"         test "$(sysctl -n net.bridge.bridge-nf-call-iptables)" = 1
check "vm.overcommit_memory=1"            test "$(sysctl -n vm.overcommit_memory)" = 1
check "crio active"                       systemctl is-active --quiet crio
check "crictl talks to CRI-O"             crictl info
check "kubelet enabled"                   systemctl is-enabled --quiet kubelet
check "flexvolume dir exists"             test -d /usr/libexec/kubernetes/kubelet-plugins/volume/exec
check "no CRI-O default bridge CNI"       sh -c '! ls /etc/cni/net.d/*crio* 2>/dev/null'
if [ -n "${EXPECT_K8S:-}" ]; then
  check "kubelet v${EXPECT_K8S}"          sh -c "kubelet --version | grep -q 'v${EXPECT_K8S}\$'"
  check "kubeadm v${EXPECT_K8S}"          sh -c "kubeadm version -o short | grep -qx 'v${EXPECT_K8S}'"
fi

echo "== Filesystem layout"
for m in /var/log /var/lib/containers /var/lib/kubelet; do
  check "separate filesystem ${m}"        findmnt -n "${m}"
done
case "${ROLE:-}" in
  worker)       check "separate filesystem /var/data" findmnt -n /var/data ;;
  controlplane) check "separate filesystem /var/lib/etcd" findmnt -n /var/lib/etcd ;;
  *)            echo "INFO ROLE unset: skipping role-specific mounts" ;;
esac
check "/data -> /var/data"                test "$(readlink /data)" = var/data

exit "${fail}"
