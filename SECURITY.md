# Security

## Reporting a vulnerability

Open a [GitHub issue](https://github.com/1121citrus/aws-backup-base/issues)
or email the maintainer directly. Please include:

- A description of the vulnerability and its potential impact
- Steps to reproduce or a proof-of-concept
- The affected version(s)

## Security design

### Base image

The final image is built on Alpine Linux, chosen for its minimal package
set and small attack surface. The base image digest is pinned in the
`Dockerfile` (`ALPINE_IMAGE_DIGEST`) so builds are reproducible and
immune to tag mutation. Alpine is upgraded unconditionally at build time
(`apk upgrade`) to pick up any patches released since the pinned digest.

### Supercronic

supercronic is compiled from source rather than downloaded as a binary.
This allows the Go toolchain version to be controlled independently of
the upstream release cadence. The current build uses Go 1.26.2, which
patches:

| CVE | Severity | Component |
| --- | -------- | --------- |
| CVE-2026-32280 | HIGH | `crypto/x509` — denial of service |
| CVE-2026-32282 | MEDIUM | `os.Root` — symlink traversal |
| CVE-2026-33810 | HIGH | `crypto/x509` — certificate validation bypass |

Once an upstream supercronic release ships with Go >= 1.26.2 (or
>= 1.25.9), the build stage can be removed and replaced with the simpler
pre-built binary installation.

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
