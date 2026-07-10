# Security

## Reporting a vulnerability

Open a [GitHub issue](https://github.com/1121citrus/aws-backup-base/issues)
or email the maintainer directly. Please include:

- A description of the vulnerability and its potential impact
- Steps to reproduce or a proof-of-concept
- The affected version(s)

## Security design

### Base image

The final image is built on Amazon Linux 2023 (AL2023). The base image
digest is pinned in the `Dockerfile` (`AL2023_IMAGE_DIGEST`) so builds
are reproducible and immune to tag mutation. The OS is upgraded
unconditionally at build time (`dnf upgrade`) to pick up any patches
released since the pinned digest.

### Supercronic

supercronic is compiled from source in a dedicated Docker build stage.
The version is pinned via `SUPERCRONIC_VERSION` and the Go toolchain is
pinned via `SUPERCRONIC_BUILDER_IMAGE`.

This avoids waiting for upstream binary releases when Go stdlib CVE fixes
land in Go first. The current builder pin (`golang:1.26.5-alpine`) includes
the Go fixes for:

| CVE | Severity | Component |
| --- | -------- | --------- |
| CVE-2026-33811 | HIGH | `net` resolver memory issue via cgo DNS |
| CVE-2026-33814 | HIGH | `net/http` HTTP/2 SETTINGS frame handling |
| CVE-2026-39820 | HIGH | `net/mail` address parsing denial of service |
| CVE-2026-39836 | HIGH | `net` panic on NUL-byte input to dial/lookup |
| CVE-2026-42499 | HIGH | `mime` phrase parsing denial of service |
| CVE-2026-42504 | HIGH | `mime` header decoding denial of service |

### No secrets in the image

No AWS credentials, tokens, or passwords are baked into this image or
any layer of it. Child images must mount credentials at runtime (e.g.,
via Docker secrets or environment variables injected by the orchestrator).

### Vulnerability scanning

Every build is scanned with three tools:

| Tool | Scope | Gate |
| ---- | ----- | ---- |
| Trivy | CRITICAL and HIGH CVEs in the final image | Blocking |
| Grype | All severities in the final image | Blocking |
| Docker Scout | CVEs reported by Docker's advisory feed | Blocking |

Scans are also run on a weekly schedule via GitHub Actions to catch
newly published CVEs between releases.

### Trivy suppression policy

When a fix is published upstream but the patched RPM is not yet available
in the AL2023 repositories, the CVE is temporarily recorded in
`.trivyignore` with the expected fixed package version.

Current temporary Trivy suppressions include:

- `CVE-2026-4046` (`glibc`, pending `2.34-231.amzn2023.0.4`)
- `CVE-2026-33845` (`gnutls`, pending `3.8.3-8.amzn2023.0.4`)
- `CVE-2026-48863` (`libsolv`, pending `0.7.22-1.amzn2023.0.4`)
- `CVE-2026-48864` (`libsolv`, pending `0.7.22-1.amzn2023.0.4`)
- `CVE-2026-9149` (`libsolv`, pending `0.7.22-1.amzn2023.0.4`)
- `CVE-2026-9150` (`libsolv`, pending `0.7.22-1.amzn2023.0.4`)
- `CVE-2026-3644` (`python3`, pending `3.9.25-1.amzn2023.0.5`)
- `CVE-2026-4786` (`python3`, pending `3.9.25-1.amzn2023.0.5`)
- `CVE-2026-6100` (`python3`, pending `3.9.25-1.amzn2023.0.5`)
- `CVE-2026-1703` (`python3-pip-wheel`, pending
  `21.3.1-2.amzn2023.0.17`)

Remove each suppression as soon as the corresponding fixed RPM is
available in AL2023 and adopted by the image build.

### Grype false-positive suppression

AL2023 ships backported security fixes inside the *same* upstream version
string as the unpatched release. Grype reads the dist-info `METADATA` file
(which still reports the old upstream version) and flags the package as
vulnerable even though the installed RPM already carries the fix.

Confirmed false positives are recorded in `.grype.yaml` with:

- the GHSA identifier grype uses to match the finding
- the Amazon Linux Security Advisory (ALAS) that confirms the fix is present

To audit the suppressions, check whether a newer RPM is available:

```
dnf check-update python3-urllib3 python3-setuptools
```

If a newer RPM is released, reassess the corresponding entry and remove it
from `.grype.yaml` when the dist-info version string is updated.

### Filesystem permissions

Scripts are installed with the minimum required permissions:

| Path | Mode |
| ---- | ---- |
| `/usr/local/include/common-functions` | `0644` (read-only) |
| `/usr/local/bin/healthcheck-base` | `0755` (executable) |
| `/usr/local/bin/startup-base` | `0755` (executable) |
| `/usr/local/bin/supercronic` | `0755` (executable) |

No `setuid` or `setgid` bits are set. Child images are expected to run
as a non-privileged user created in their own `Dockerfile`.

## AGPL-3.0 copyleft obligations

This project is licensed under AGPL-3.0-or-later. If you modify this
image and make it available over a network, you must make the
corresponding source code available to users of that network service.
See [LICENSE.md](LICENSE.md) for the full terms.
