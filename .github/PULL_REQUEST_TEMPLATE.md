# Pull Request

## Description

What does this PR change and why?

## Type of change

- [ ] Bug fix
- [ ] New feature
- [ ] Documentation
- [ ] CI / tooling
- [ ] New distro / version

## Impact

- Upgrades / rollbacks (`bootc upgrade`, `bootc rollback`):
- Persistence (`/etc` merge, `/var` content):
- Architectures (x86_64 / aarch64):

## Checklist

- [ ] `sudo scripts/build.sh <distro> <version>` passes (includes `bootc container lint`)
- [ ] `scripts/scan.sh` passes with no new fixable High/Critical CVEs
- [ ] Boot test passes (`scripts/boot-test.sh`, or green in CI)
- [ ] shellcheck passes for changed scripts
- [ ] New grype ignores have a reason and a review date
- [ ] Follows the [contributing guidelines](../CONTRIBUTING.md)

## Related issues

Closes #
