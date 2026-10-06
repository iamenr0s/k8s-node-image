# Security Policy

## Supported Versions

Only the current image for each supported Kubernetes minor receives security fixes.
Images are rebuilt nightly on the latest [bootc-images](https://github.com/iamenr0s/bootc-images)
base and the Kubernetes/CRI-O package streams. Deployed nodes pick fixes up with `bootc upgrade`.

| Version | Supported |
| ------- | --------- |
| Current `k8s-node` image for the supported Kubernetes minor (e.g. `k8s-node:1.37`) | ✅ |
| Per-arch tags (`-amd64`, `-arm64`) | ✅ (same builds as the version tag) |
| Pinned digests of older builds, older Kubernetes minors | ❌ |

## Reporting a Vulnerability

Please **do not** open a public issue for security vulnerabilities.

Instead, report them privately via [GitHub private vulnerability reporting](https://github.com/iamenr0s/k8s-node-image/security/advisories/new).

Include a description of the issue, steps to reproduce, and the affected image tag,
node role, architecture and deployment method (bootc-image-builder, `bootc switch`, ...) if relevant.

You can expect an initial response within 7 days. Once the issue is confirmed, a fix
will be released as soon as practical (through the CVE gate and build pipeline), and
you will be credited in the release notes unless you prefer otherwise.

Vulnerabilities in the base userspace belong in
[bootc-images](https://github.com/iamenr0s/bootc-images/security/advisories/new);
Kubernetes and CRI-O issues belong upstream.

## Automated scanning

Every build is gated on grype and trivy: no fixable High/Critical findings before
push (`scripts/scan.sh`). Published images are signed with cosign
(`files/etc/containers/policy.json` enforces the signature on nodes).
