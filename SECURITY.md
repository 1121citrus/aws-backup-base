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
land in Go first. The current builder pin (`golang:1.27.3-alpine`) includes
the Go fixes for:

| CVE | Severity | Component |
| --- | -------- | --------- |
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

Current temporary Trivy suppressions include:

- `CVE-2026-113470` (`ca-certificates`, pending `2025.2.76-1.0.amzn2023.0.4`)
- `CVE-2026-92392` (`curl-minimal`/`libcurl-minimal`, pending
  `8.21.0-5.amzn2023.0.3`)
- `CVE-2026-107161` (`cyrus-sasl-lib`, pending `2.1.27-18.amzn2023.0.4`)
- `CVE-2026-78659`, `CVE-2026-78667`, `CVE-2026-94440` (`libcap`, pending
  `2.73-1.amzn2023.0.8`)
- `CVE-2026-103111`, `CVE-2026-86145`, `CVE-2026-89156`, `CVE-2026-89160`
  (`pcre2`/`pcre2-syntax`, pending `10.40-1.amzn2023.0.5`)
- `CVE-2026-19553` (`python3`/`python3-libs`, pending
  `3.9.25-1.amzn2023.0.11`)

The previously listed CVEs (`glib2` CVE-2026-58010 through 58016, `libacl`
CVE-2026-54369/54370, `python3`/`python3-libs` CVE-2026-0864/11940/11972/
3276/9669, `openssl-fips-provider-latest`/`openssl-libs` CVE-2026-14456)
are fixed in the installed RPM versions as of the 2026-10-28 AL2023 digest
refresh (`sha256:c04a1012...be9b6`) — confirmed via `dnf list
--showduplicates` against the live AL2023 repo mirror, where each package's
installed version is no longer the latest or no longer appears as
vulnerable — and their `.trivyignore` entries have been removed
accordingly. The same digest refresh surfaced the newer batch above:
`./build`'s own Trivy stage reuses a long-lived local DB cache
(`--skip-db-update`) that predated their disclosure, so they were only
caught by re-scanning with a freshly updated Trivy DB (`./build --cache
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

As of the 2026-10-28 review, Grype's unfiltered (all-severity) scan
reports more rows than Trivy's HIGH/CRITICAL-only gate does. Most of them
are **the same CVEs already tracked in `.trivyignore`** — Grype just also
surfaces them because it doesn't apply a severity filter:

| Grype package(s) | ALAS | Same CVE(s), already in `.trivyignore` |
| ----------------- | ---- | --------------------------------------- |
| `curl-minimal` / `libcurl-minimal` | ALAS2023-2026-3267 | CVE-2026-92392 |
| `libcap` | ALAS2023-2026-3255 | CVE-2026-78659, 78667, 94440 |
| `python3` / `python3-libs` | ALAS2023-2026-3278 | CVE-2026-19553 |
| `cyrus-sasl-lib` | ALAS2023-2026-3290 | CVE-2026-107161 |
| `ca-certificates` | ALAS2023-2026-3306 | CVE-2026-113470 |
| `pcre2` / `pcre2-syntax` | ALAS2023-2026-3269 | CVE-2026-103111, 86145, 89156, 89160 |

The remaining rows are findings Grype surfaces that Trivy doesn't report at
all (Python packages, where Grype reads PyPI dist-info metadata that Trivy
doesn't check, and `perl-*`, which is below Trivy's HIGH/CRITICAL floor).
These are confirmed **not** version-string false positives: `rpm -q
--changelog` on each package inside the built image shows no changelog
entry addressing the specific CVE, and `dnf list --showduplicates` against
the live AL2023 repo (both `linux/amd64` and `linux/arm64`) confirms the
installed build is still the newest one available.

| CVE | Package(s) | Installed | Fix |
| --- | ---------- | --------- | --- |
| CVE-2022-40896 (GHSA-mrwq-x4v8-fh7p) | `python3-pygments` | `2.7.4-1.amzn2023.0.3` | `2.15.0` (upstream PyPI; no AL2023 RPM yet) |
| CVE-2026-59890 (GHSA-h35f-9h28-mq5c) | `python3-setuptools` | `59.6.0-2.amzn2023.0.6` | `83.0.0` (upstream PyPI; no AL2023 RPM yet) |
| GHSA-xmj3-9gf7-h52w | `python3-setuptools` | `59.6.0-2.amzn2023.0.6` | `84.1.0` (upstream PyPI; no AL2023 RPM yet) |
| CVE-2026-15534, CVE-2026-19487 (ALAS2023-2026-3279) | `perl-*` (interpreter, libs, and ~60 `perl-<Module>` subpackages) | `*-477.amzn2023.0.10` | `*-477.amzn2023.0.11` |

The `perl-*` row is a mirror-propagation gap, not an unpublished fix:
`alas.aws.amazon.com/AL2023/ALAS2023-2026-3279.html` already lists the
built `...amzn2023.0.11` RPMs for every `perl-*` subpackage, but
`dnf list --showduplicates perl-libs` against the live `amazonlinux:2023`
repo mirror (verified on both architectures) still tops out at `.0.10` —
the advisory shipped before the package mirror caught up. Re-check with
the same `dnf list --showduplicates` command; once `.0.11` appears, bump
the base image (a fresh `dnf upgrade` picks it up with no Dockerfile
change needed) and re-scan.

None of the rows above are suppressed in `.grype.yaml` — that file
documents only confirmed version-string false positives, and none of
these are that. They remain visible in Grype's plain-text output on every
build, which is expected and does not indicate a regression; re-run the
`dnf list --showduplicates` checks above periodically to catch the moment
a fix becomes installable.

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
