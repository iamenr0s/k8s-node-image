---
name: Bug report
about: Report a problem with one of the images
title: ''
labels: bug
assignees: ''
---

## Describe the bug

A clear and concise description of what the bug is.

## To reproduce

How you built or deployed the image:

```bash
sudo bootc switch quay.io/iamenr0s/centos-hardened-bootc:10
```

## Expected behavior

What you expected to happen.

## Actual behavior

What actually happened. Include relevant output/logs (`bootc status`, `journalctl -b`, serial console):

```
paste output here
```

## Environment

- Image and tag (e.g. `quay.io/iamenr0s/centos-hardened-bootc:10`):
- Registry (Docker Hub / Quay):
- Architecture (amd64 / arm64):
- Deployment (bootc-image-builder type / `bootc install` / `bootc switch`):
- Platform (bare metal, KVM, cloud provider, ...) and firmware (UEFI / BIOS):

## Additional context

Anything else that might help (grype/trivy scan output, `bootc container lint` output, etc.).
