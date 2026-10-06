# Kubernetes node OS image, layered on iamenr0s/bootc-images.
#
# Build context: this directory.
#   sudo podman build -t localhost/k8s-node:1.37 .
#
# Everything the node runs (kernel, CRI-O, kubelet, kubeadm, config defaults)
# lives in this image. Hosts never run dnf: they `bootc upgrade` / `bootc switch`.

# Pin the base by digest in production (Renovate bumps the digest nightly).
# renovate: datasource=docker depName=quay.io/iamenr0s/rockylinux-hardened-bootc
ARG BASE_IMAGE=quay.io/iamenr0s/rockylinux-hardened-bootc:10
FROM ${BASE_IMAGE}

# The Kubernetes minor selects the pkgs.k8s.io and CRI-O package streams;
# K8S_VERSION pins the exact kubelet/kubeadm/kubectl patch release.
ARG K8S_MINOR=v1.37
# renovate: datasource=github-releases depName=kubernetes/kubernetes
ARG K8S_VERSION=1.37.1
ARG CRIO_MINOR=v1.37
# Optional exact CRI-O version (empty = newest in CRIO_MINOR stream)
ARG CRIO_VERSION=
# Extra host packages a CSI driver or agent expects on the node
# (e.g. "iscsi-initiator-utils nfs-utils device-mapper-multipath" for Longhorn/Ceph).
ARG EXTRA_PACKAGES=

# 1. Packages (repos exist only for this RUN; nothing is left enabled on the host)
RUN --mount=type=bind,source=scripts/node-setup.sh,target=/tmp/node-setup.sh \
    K8S_MINOR="${K8S_MINOR}" K8S_VERSION="${K8S_VERSION}" \
    CRIO_MINOR="${CRIO_MINOR}" CRIO_VERSION="${CRIO_VERSION}" \
    EXTRA_PACKAGES="${EXTRA_PACKAGES}" \
    bash /tmp/node-setup.sh install

# 2. Node configuration (sshd, sysctl, kargs, CRI-O, audit, units, helpers)
COPY files/ /

# 3. Enable units, relocate /var content to tmpfiles.d, lint
RUN --mount=type=bind,source=scripts/node-setup.sh,target=/tmp/node-setup.sh \
    bash /tmp/node-setup.sh finalize

LABEL containers.bootc=1 \
      ostree.bootable=1 \
      org.opencontainers.image.title="k8s-node" \
      org.opencontainers.image.description="Immutable Kubernetes node (CRI-O + kubeadm) on bootc-images" \
      io.k8s.version="${K8S_VERSION}"
