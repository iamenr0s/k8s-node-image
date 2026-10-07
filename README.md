# K8S Node Image

[![build](https://img.shields.io/github/actions/workflow/status/iamenr0s/k8s-node-image/k8s-node.yml?label=build&logo=github)](https://github.com/iamenr0s/k8s-node-image/actions/workflows/k8s-node.yml)
[![Renovate](https://img.shields.io/badge/renovate-enabled-brightgreen?logo=renovatebot)](renovate.json)
[![License](https://img.shields.io/github/license/iamenr0s/k8s-node-image)](LICENSE)

Immutable Kubernetes nodes built with [bootc](https://github.com/bootc-dev/bootc): one signed
container image per Kubernetes minor (kernel, CRI-O, kubelet/kubeadm/kubectl and node config),
layered on [bootc-images](https://github.com/iamenr0s/bootc-images) (Rocky Linux 10).
The same image becomes a QCOW2 disk for VMs and an unattended ISO for bare metal.
Hosts never run `dnf`: they `bootc upgrade` / `bootc switch` and roll back atomically.

## Layout

| Path | Purpose |
|---|---|
| `Containerfile` | Image build; `ARG`s pin the base, `K8S_VERSION`, CRI-O, extra host packages |
| `scripts/node-setup.sh` | Package install and image finalisation (runs inside the build) |
| `files/` | Config copied over `/`: sysctl, modules, sshd, CRI-O, audit, systemd units, tmpfiles |
| `bib/` | bootc-image-builder configs (QCOW2 per role, kickstart ISO) |
| `kubeadm/` | Example `kubeadm` config for the first control-plane node |
| `optional/` | Alternative ways to bake in the `k8sadmin` account and SSH key |
| `policies/` | grype and trivy CVE gate policies (ignores need a reason and review date) |
| `scripts/` | `build`, `scan`, `disk`, `seed`, `qemu-run`, `vm-test`, `iso-test`, `validate-node` |

## Quick start

Needs Linux, rootful podman and KVM.

```bash
# 1. Build the image (runs bootc container lint)
sudo scripts/build.sh localhost/k8s-node:1.37

# 2. CVE gate: fails on fixable High/Critical (grype + trivy)
sudo podman save --format oci-dir -o /tmp/oci localhost/k8s-node:1.37
scripts/scan.sh /tmp/oci

# 3. Admin SSH key baked into the disk (key-only login, passwords are refused)
mkdir -p keys && ssh-keygen -t ed25519 -N '' -f keys/k8sadmin_ed25519

# 4. Disk image: qcow2 | raw | anaconda-iso, role worker | controlplane
sudo scripts/disk.sh qcow2 worker localhost/k8s-node:1.37 output/worker

# 5. Boot it under QEMU and run the node checks
sudo EXPECT_K8S=1.37.1 ROLE=worker scripts/vm-test.sh output/worker/qcow2/disk.qcow2
sudo scripts/iso-test.sh <install.iso>   # unattended ISO install (from disk.sh anaconda-iso)
```

`scripts/qemu-run.sh <disk.qcow2> [seed.iso]` boots a disk interactively (SSH on `localhost:2222`).
The ISO picks its role from `k8s.role=controlplane|worker` on the kernel command line and
installs onto the first non-removable disk of at least 240 GiB.

## Using a node

- **Control plane:** edit `kubeadm/kubeadm-config.yaml` (node IP, API endpoint, pod CIDR),
  then `sudo kubeadm init --config kubeadm-config.yaml`. CRI-O is the runtime and Cilium
  is assumed (kube-proxy phase skipped; remove that line for another CNI).
- **Worker:** `sudo kubeadm join ...` with the token from the control plane.
- **Persistence:** state lives in `/var` (kubelet, etcd, `/var/data`); `/usr` is read-only and
  `/etc` is three-way merged on upgrade. New `/var` paths need a `tmpfiles.d` entry.
- **Maintenance:** `k8s-node-update.timer` checks for a new image every 6 h; control planes
  take etcd snapshots (`etcd-snapshot.timer`); `k8s-safe-rollback` reverts a bad upgrade.
- **Extra host packages** (iSCSI/NFS/multipath for CSI drivers): build with
  `--build-arg EXTRA_PACKAGES="iscsi-initiator-utils nfs-utils device-mapper-multipath"`.

## CI/CD

[`k8s-node.yml`](.github/workflows/k8s-node.yml) runs on push, PR and nightly:
`lint` (shellcheck, actionlint, hadolint) → `build` (amd64/arm64 + CVE gate) → `disk`
(QCOW2 per role, ISO) → `validate` / `validate-iso` (boot in QEMU) → `publish`
(multi-arch manifest signed with cosign) → `release`. Publishing needs the `release`
environment secrets `COSIGN_PRIVATE_KEY` and `COSIGN_PASSWORD`; nodes verify the signature
via `files/etc/containers/policy.json`. Renovate bumps the base digest, Kubernetes *patch*
releases, scanners, cosign and Actions; a Kubernetes minor is a deliberate, drained upgrade.

### Cosign setup (one-time)

```bash
cosign generate-key-pair                      # writes cosign.key + cosign.pub; set a password
cp cosign.pub files/etc/pki/containers/k8s-node-cosign.pub   # baked into the image, used by policy.json
gh secret set COSIGN_PRIVATE_KEY --env release < cosign.key
gh secret set COSIGN_PASSWORD    --env release   # prompts for the password
shred -u cosign.key                           # keep only an offline backup
```

Rotating the key: repeat, commit the new `.pub`, and ship an image that carries it
*before* publishing images signed with the new key (nodes verify with the key they already have).
Verify a published image: `cosign verify --key cosign.pub ghcr.io/iamenr0s/k8s-node:<tag>`.

**Repo recreated?** GHCR packages stay linked to the old repo, so `publish` fails with
`StatusCode: 403` on push. Fix: package settings → *Manage Actions access* → add this repo
as **Write** (or delete the package and let the next run recreate it).

## Contributing

Contributions are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md) for the
local pipeline commands and pull request checklist. This project follows the
[Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md).

## Security

See [SECURITY.md](SECURITY.md) — GitHub private vulnerability reporting, no
public issues for security bugs.

## License

This project is licensed under the [MIT License](LICENSE).

## Author Information

Author: iamenr0s
