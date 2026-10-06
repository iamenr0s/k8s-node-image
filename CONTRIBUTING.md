# Contributing

Thanks for taking the time to contribute to `k8s-node-image`!

## Getting started

1. Fork the repository and create your branch from `main`.
2. You need rootful `podman`, plus `shellcheck`, `actionlint`, `hadolint`, `grype` and
   `trivy` for the checks below. For the VM boot test you also need
   `qemu-system-x86_64`, OVMF and `/dev/kvm`.

## Making changes

- Keep changes small and focused, one topic per pull request.
- The image is layered on [bootc-images](https://github.com/iamenr0s/bootc-images).
  Don't rebuild the rootfs or switch to another base.
- Hosts are immutable: no `dnf` on the node, no secrets, passwords or keys in the image.
  Packages are installed at build time in `scripts/node-setup.sh`; `/var` content needs a
  `tmpfiles.d` entry, and `bootc container lint` enforces that. Config defaults live under
  `files/` (see `.claude/skills/bootc-node-rules` for the `/etc` merge and `/usr` rules).
- Kubernetes patch bumps are automated (Renovate). A minor upgrade is a deliberate,
  drained kubeadm procedure, so change `K8S_MINOR`/`CRIO_MINOR` by hand.
- Vulnerability ignores in `policies/grype.yaml` need a reason and a review date
  (`scripts/check-policy-dates.sh` fails once a date passes).

## Testing

Before opening a pull request, run the checks for what you touched:

```bash
sudo scripts/build.sh localhost/k8s-node:1.37          # build + bootc container lint
sudo podman save --format oci-dir -o /tmp/oci localhost/k8s-node:1.37
scripts/scan.sh /tmp/oci                               # grype + trivy CVE gate
sudo scripts/disk.sh qcow2 worker localhost/k8s-node:1.37 output/worker
sudo EXPECT_K8S=1.37.1 ROLE=worker scripts/vm-test.sh output/worker/qcow2/disk.qcow2   # needs KVM
shellcheck scripts/*.sh files/usr/libexec/k8s-node/*
actionlint && hadolint Containerfile
```

## Submitting a pull request

1. Make sure the checks above pass.
2. Fill in the pull request template.
3. A maintainer will review your PR. CI (lint, build, CVE gate, boot test) must be green before merge.

## Reporting bugs and requesting features

Use the issue templates. They ask for the details (Kubernetes version, node role,
architecture, deployment method) needed to reproduce a problem. Report security issues
privately as described in [SECURITY.md](SECURITY.md).

## Code of Conduct

This project follows the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md). By participating you agree to abide by it.
