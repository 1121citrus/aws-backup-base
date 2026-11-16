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
unconditionally at build time (`dnf upgrade --releasever=latest`) to pick
up any patches released since the pinned digest.

The `--releasever=latest` flag matters: AL2023 locks `dnf` to the release
the base image was cut from, so a plain `dnf upgrade` can only reach
packages published for that release. On 2026-11-15 even the newest
`amazonlinux:2023` image (release `2023.12.20261102`) still shipped
vulnerable `glibc`, `rpm`, and `sqlite-libs` builds whose fixes existed
only in the latest release repository, so refreshing the digest alone did
not clear the gating Trivy findings. Keep the flag on both the
`dnf upgrade` and the `dnf install` commands.

`python3-pygments` is excluded (`--exclude=python3-pygments`). It is only
an optional "Recommends" of `python3-prompt-toolkit`, nothing in the image
uses it, and it carries an unpatched Grype finding (see below).

### Supercronic

supercronic is compiled from source in a dedicated Docker build stage.
The version is pinned via `SUPERCRONIC_VERSION` and the Go toolchain is
pinned via `SUPERCRONIC_BUILDER_IMAGE`.

This avoids waiting for upstream binary releases when Go stdlib CVE fixes
land in Go first. The current builder pin (`golang:1.27.4-alpine`) includes
the Go fixes for:

| CVE | Severity | Component |
| --- | -------- | --------- |
| GO-2026-6859 | Unknown (Grype) | Go `stdlib`, fixed in Go 1.27.4 |
| CVE-2026-111943 | HIGH | `crypto/x509` man-in-the-middle via untrusted intermediate certificates |
| CVE-2026-78667 | HIGH | `net/http` denial of service via crafted HTTP Range headers |
| CVE-2026-78669 | HIGH | `net/http/internal/http2` denial of service via excessive HTTP/2 SETTINGS frames |
| CVE-2026-97031 | HIGH | `crypto/tls` denial of service via multiple ECH outer extension references |

**Important:** the Go toolchain embedded in the compiled `supercronic`
binary tracks `SUPERCRONIC_BUILDER_IMAGE`'s own Go version only because the
build (`Dockerfile`) sets `GOTOOLCHAIN=local` — this forces `go install` to
use whatever Go ships inside the pinned builder image. An earlier revision
hardcoded `GOTOOLCHAIN=go1.27.0`, which silently pinned the embedded Go
stdlib to `go1.27.0` regardless of the builder image tag; bumping
`SUPERCRONIC_BUILDER_IMAGE` alone did not change the embedded Go version
until that hardcoded value was replaced with `local`. Keep `GOTOOLCHAIN=local`
so a future builder-image bump actually takes effect.

### No secrets in the image

No AWS credentials, tokens, or passwords are baked into this image or
any layer of it. Child images must mount credentials at runtime (e.g.,
via Docker secrets or environment variables injected by the orchestrator).

### Vulnerability scanning

Every build runs Trivy and Grype against the final image:

| Tool | Scope | Gate |
| ---- | ----- | ---- |
| Trivy | CRITICAL and HIGH CVEs | Blocking — `./build` passes `--exit-code 1`; a finding not covered by `.trivyignore` fails the build. |
| Grype | All severities | Advisory only — `./build` runs Grype and prints its findings, but the invocation has no `--fail-on` flag, so Grype's own exit code (0 regardless of findings) never fails the build. |
| Docker Scout | — | Not implemented. `BUILD_SCAN_SCOUT` is documented in `./build --help` and the stage list, but no corresponding scan stage exists in the script. |

Grype's output is still worth reading on every build: it covers Medium/Low
severities Trivy's `--severity HIGH,CRITICAL` filter skips, and its own
findings should be triaged the same way as a Trivy finding (fix if a build
is available, document if not) even though it cannot block the build
itself. See "Known unfixed Grype findings" below.

Scans are also run on a weekly schedule via GitHub Actions to catch
newly published CVEs between releases.

### Trivy suppression policy

When a fix is published upstream but the patched RPM is not yet available
in the AL2023 repositories, the CVE is temporarily recorded in
`.trivyignore` with the expected fixed package version.

There are currently no Trivy suppressions. As of the 2026-11-15 AL2023
digest refresh (`sha256:3ccfbe80...2675b`) combined with
`dnf upgrade --releasever=latest`, an unfiltered Trivy scan (no
`.trivyignore`, severities MEDIUM and above, fixable findings only)
reports zero findings. The 11 entries previously listed (`ca-certificates`
CVE-2026-113470, `curl-minimal`/`libcurl-minimal` CVE-2026-92392,
`cyrus-sasl-lib` CVE-2026-107161, `libcap` CVE-2026-78659/78667/94440,
`pcre2`/`pcre2-syntax` CVE-2026-103111/86145/89156/89160, and
`python3`/`python3-libs` CVE-2026-19553) are all fixed in the installed
RPMs and were removed from `.trivyignore`.

`./build`'s own Trivy stage reuses a long-lived local DB cache
(`--skip-db-update`), so newly disclosed CVEs are only caught after
re-scanning with a freshly updated Trivy DB (`./build --cache
reset=trivy`).

Remove each suppression as soon as the corresponding fixed RPM is
available in AL2023 and adopted by the image build. Verify availability
with `dnf list --showduplicates <package>` run inside a fresh
`amazonlinux:2023` container.

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

### Known unfixed Grype findings (not false positives)

As of the 2026-11-15 review, Grype's unfiltered (all-severity) scan
reports only the `python3-setuptools` rows below. The earlier
`.trivyignore` overlap rows (`curl-minimal`, `libcap`, `python3`,
`cyrus-sasl-lib`, `ca-certificates`, `pcre2`) and the `perl-*`
ALAS2023-2026-3279 mirror-propagation gap are resolved by
`dnf upgrade --releasever=latest`. The `python3-pygments` row
(CVE-2022-40896, GHSA-mrwq-x4v8-fh7p) is resolved by no longer
installing the package (see "Base image" above).

The remaining rows are confirmed **not** version-string false positives:
`rpm -q --changelog` inside the built image shows no changelog entry
addressing these CVEs, and `dnf --releasever=latest list --showduplicates
python3-setuptools` confirms the installed build is still the newest one
available. `python3-setuptools` is a hard dependency of
`python3-ruamel-yaml` (required by `awscli-2`), so it cannot be removed.

| CVE | Package(s) | Severity | Installed | Fix |
| --- | ---------- | -------- | --------- | --- |
| CVE-2026-59890 (GHSA-h35f-9h28-mq5c) | `python3-setuptools` | Medium | `59.6.0-2.amzn2023.0.6` | `83.0.0` (upstream PyPI; no AL2023 RPM yet) |
| GHSA-xmj3-9gf7-h52w | `python3-setuptools` | Low | `59.6.0-2.amzn2023.0.6` | `84.1.0` (upstream PyPI; no AL2023 RPM yet) |

Neither row is suppressed in `.grype.yaml` — that file documents only
confirmed version-string false positives. They remain visible in Grype's
plain-text output on every build, which is expected and does not indicate
a regression; re-run the `dnf list --showduplicates` check above
periodically to catch the moment a fix becomes installable.

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
