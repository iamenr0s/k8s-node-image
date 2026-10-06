#!/usr/bin/env bash
# Build-time setup for the k8s-node bootc image. Runs inside the Containerfile.
#   node-setup.sh install   -> add CRI-O + Kubernetes packages
#   node-setup.sh finalize  -> enable units, make /var bootc-safe, lint
set -euo pipefail

install() {
  : "${K8S_MINOR:?}" "${K8S_VERSION:?}" "${CRIO_MINOR:?}"

  # Build-only repos. pkgs.k8s.io hosts Kubernetes; CRI-O's stable streams are
  # published on the openSUSE build service (mirror both for reproducible builds).
  cat > /etc/yum.repos.d/kubernetes.repo <<EOF
[kubernetes]
name=Kubernetes ${K8S_MINOR}
baseurl=https://pkgs.k8s.io/core:/stable:/${K8S_MINOR}/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/${K8S_MINOR}/rpm/repodata/repomd.xml.key
EOF
  cat > /etc/yum.repos.d/cri-o.repo <<EOF
[cri-o]
name=CRI-O ${CRIO_MINOR}
baseurl=https://download.opensuse.org/repositories/isv:/cri-o:/stable:/${CRIO_MINOR}/rpm/
enabled=1
gpgcheck=1
gpgkey=https://download.opensuse.org/repositories/isv:/cri-o:/stable:/${CRIO_MINOR}/rpm/repodata/repomd.xml.key
EOF

  # /opt -> var/opt in bootc-images, and /var/opt only exists at runtime
  # (tmpfiles). RPMs that write to /opt (kubernetes-cni) need the target now.
  mkdir -p /var/opt

  local crio="cri-o"
  [ -n "${CRIO_VERSION:-}" ] && crio="cri-o-${CRIO_VERSION}"

  # br_netfilter ships in kernel-modules-extra on EL10; match the image kernel exactly.
  local kmod
  kmod="kernel-modules-extra-$(rpm -q --qf '%{VERSION}-%{RELEASE}' kernel-core)"

  # shellcheck disable=SC2086  # EXTRA_PACKAGES is a word list on purpose
  dnf -y install --setopt=install_weak_deps=False \
    "${crio}" \
    "kubelet-${K8S_VERSION}" "kubeadm-${K8S_VERSION}" "kubectl-${K8S_VERSION}" cri-tools \
    "${kmod}" conntrack-tools iproute-tc ethtool socat \
    iptables-nft nftables audit lvm2 \
    ${EXTRA_PACKAGES:-}

  # Fail the build if the resolver picked anything other than the pinned patch.
  for p in kubelet kubeadm kubectl; do
    v="$(rpm -q --qf '%{VERSION}' "${p}")"
    [ "${v}" = "${K8S_VERSION}" ] || { echo "${p} is ${v}, expected ${K8S_VERSION}" >&2; exit 1; }
  done

  # Kubernetes needs swap off (failSwapOn). Fedora bases may carry zram defaults.
  dnf -y remove zram-generator-defaults 2>/dev/null || true

  # The disk layouts in bib/ put / on an LVM logical volume. The base initramfs
  # has no lvm module, so rebuild it with the base's own dracut arguments plus lvm.
  local kver
  kver="$(basename "$(ls -d /usr/lib/modules/*/)")"
  dracut --force --no-hostonly --reproducible --add lvm \
    --kver "${kver}" "/usr/lib/modules/${kver}/initramfs.img"
  # dracut's lvm probing leaves runtime-only dirs behind (bootc lint: nonempty-run-tmp).
  rm -rf /run/lvm /run/lock/lvm
  rmdir /run/lock 2>/dev/null || true

  rm -f /etc/yum.repos.d/kubernetes.repo /etc/yum.repos.d/cri-o.repo
}

finalize() {
  # CNI plugins shipped by RPM into /opt/cni/bin would land in /var/opt, which
  # bootc only seeds on first install and never updates. Keep image-owned
  # plugins in /usr/libexec/cni; /opt/cni/bin stays writable for the cluster
  # CNI DaemonSet (Cilium/Calico install their own binaries there at runtime).
  if [ -d /var/opt/cni/bin ]; then
    mkdir -p /usr/libexec/cni
    cp -an /var/opt/cni/bin/. /usr/libexec/cni/
  fi
  rm -rf /var/opt/cni

  # CRI-O's packaged bridge CNI config would win over the cluster CNI.
  rm -f /etc/cni/net.d/*crio*

  # kube-controller-manager mounts this hostPath with DirectoryOrCreate;
  # /usr is read-only at runtime, so it has to exist in the image.
  mkdir -p /usr/libexec/kubernetes/kubelet-plugins/volume/exec

  # Toplevel /data for application storage, backed by /var/data (a volume).
  ln -sfn var/data /data

  # Rocky's repo key file also carries a v6 post-quantum key (ML-DSA-87+Ed448)
  # that bootc-image-builder's rpmkeys rejects, failing anaconda-iso builds.
  # Packages are signed with the RSA key (first block), so point the repos at it.
  # ponytail: assumes RSA is block 1; a reorder fails the ISO build loudly.
  # Drop once bib's buildroot accepts v6 keys. Hosts never run dnf.
  local key=/etc/pki/rpm-gpg/RPM-GPG-KEY-Rocky-10
  if [ "$(grep -c 'BEGIN PGP PUBLIC KEY BLOCK' "${key}" 2>/dev/null || echo 0)" -gt 1 ]; then
    awk '{print} /END PGP PUBLIC KEY BLOCK/ {exit}' "${key}" > "${key}-rsa"
    sed -i "s|^gpgkey=file://${key}\$|gpgkey=file://${key}-rsa|" /etc/yum.repos.d/rocky*.repo
  fi

  chmod 0440 /etc/sudoers.d/90-k8s-node
  chmod 0755 /usr/libexec/k8s-node/*

  # Presets make the enablement canonical (same approach as bootc-images).
  systemctl preset-all

  # /var is per-host state. Drop build leftovers; anything left needs a
  # tmpfiles.d entry so it exists on hosts installed from older images too.
  dnf clean all
  rm -rf /var/cache/* /var/log/* /var/tmp/* /var/lib/dnf
  known="$(systemd-tmpfiles --cat-config | awk '$1 !~ /^#/ {print $2}')"
  find /var -mindepth 1 \( -type d -o -type l \) \
       -printf '%y /var/%P %m %u %g %l\n' | sort -k2 | while read -r type path mode user group target; do
    grep -qxF "${path}" <<<"${known}" && continue
    if [ "${type}" = l ]; then echo "L ${path} - - - - ${target}"; else echo "d ${path} 0${mode} ${user} ${group} -"; fi
  done > /usr/lib/tmpfiles.d/k8s-node-autovar.conf

  bootc container lint
}

case "${1:-}" in
  install) install ;;
  finalize) finalize ;;
  *) echo "usage: $0 install|finalize" >&2; exit 2 ;;
esac
