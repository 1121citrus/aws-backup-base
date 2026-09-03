# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.2.1] - 2026-09-03

### Fixed

- Refreshed `AL2023_IMAGE_DIGEST` to the 2026-09-03 `amazonlinux:2023`
  digest (`sha256:181f98c48832fe926f8ca3b6ffeafcce128e96e77b93d08fbe9a9bc9403ce284`),
  resolving 18 of the 19 gating Trivy HIGH findings surfaced against
  the previous 2026-07-21 digest (gawk, glib2, openssl,
  python3/python3-libs/python3.12/python3.12-libs, python3-rpm/rpm,
  rpm-build-libs, rpm-libs, rpm-sign-libs). The one remaining finding
  (`CVE-2026-14456`, openssl-fips-provider-latest/openssl-libs — fix
  `1:3.5.7-2.amzn2023.0.2` not yet published to the AL2023 repos) is
  tracked in `.trivyignore`.
- Bumped `SUPERCRONIC_VERSION` from `v0.2.47` to `v0.2.49` and the
  `SUPERCRONIC_BUILDER_IMAGE` from `golang:1.26.5-alpine` to
  `golang:1.27.0-alpine` (matching the fix already applied in
  `rotate-aws-backups`), resolving all 8 gating Go `stdlib` HIGH
  findings in the `supercronic` gobinary (CVE-2026-33818,
  CVE-2026-39821, CVE-2026-46600, CVE-2026-56853, CVE-2026-56858,
  CVE-2026-56859, CVE-2026-56860, CVE-2026-56862).
- Updated `.trivyignore` to add the new openssl-fips-provider-latest
  entry pending an upstream AL2023 package release. The pre-existing
  glib2, libacl, and cpython entries are left in place unchanged;
  their absence from the fresh gating scan was not independently
  re-verified against the new digest and may still apply.

## [1.2.0] - 2026-07-20

### Added

- `run_once_before_schedule` in `common-functions`: derivative images
  call this once from their scheduler-mode entry point, right before
  handing off to supercronic, to run the backup command once for real
  immediately. `touch_healthcheck_startup_marker`'s grace period
  expires (default 900s) long before the first real run of an
  infrequent schedule like `@daily` or `*/8 hours`, so a freshly
  deployed container previously sat unhealthy for hours waiting on a
  scheduled run that hadn't happened yet.

## [1.1.9] - 2026-07-10

### Changed

- Refresh the supercronic builder toolchain from Go 1.26.4 to Go 1.26.5
- Update the pinned `supercronic` release from v0.2.45 to v0.2.47 so the
  binary carries the current Go stdlib fixes

## [1.1.8] - 2026-07-10

### Added

- `touch_healthcheck_startup_marker` in `common-functions`: derivative
  images call this once from their scheduler-mode entry point to
  populate `HEALTHCHECK_STARTUP_FILE`, so `healthcheck-base`'s
  grace-period check actually has a marker to read. Previously,
  setting `HEALTHCHECK_STARTUP_FILE` only enabled the check without
  creating the file it depends on -- documented in README.md with the
  required call site.

### Security

- Refreshed the pinned `amazonlinux:2023` digest (2026-06-08 →
  2026-07-08). The prior pin carried 65+ unfixed HIGH CVEs across the
  AL2023 package set that the newer base's own `dnf upgrade` already
  resolves; a Trivy scan against the refreshed base reports 0
  vulnerabilities.

## [1.1.7] - 2026-06-09

### Changed

- Bump project version to 1.1.7

## [1.1.6] - 2026-06-09

### Changed

- Bump project version to 1.1.6

## [1.1.5] - 2026-06-09

### Changed

- Bump project version to 1.1.5

## [1.1.4] - 2026-06-09

### Changed

- Bump project version to 1.1.4

## [1.1.3] - 2026-05-23

### Changed

- Build `supercronic` from source in a dedicated builder stage using a
  pinned Go toolchain image (`golang:1.26.3-alpine`) instead of downloading
  pre-built release binaries
- Refresh the pinned AL2023 base digest to
  `sha256:f03d3254192161691b72be58219022adc2036bd0933aa2b6f3b744f20b2bbe8c`
- Fix Stage 3 test invocation in `build` to execute `test/run-all` directly
  with environment variables (removes invalid `env ... run` call)
- Fix Stage 5f metrics advisement invocation to run `scc --by-file /data`
  inside the container (removes host-side `--by-file` exec error)

### Security

- Update `SECURITY.md` to document source-built supercronic and the current
  Go stdlib HIGH CVE remediation coverage

## [1.1.2] - 2026-05-03

### Changed

- Bump project version to 1.1.2

## [1.1.1] - 2026-04-30

### Changed

- Add kcov-based coverage infrastructure to the repository
- Regenerate the `build` script to add test/staging integration and improve
  validation and staging help text
- Regenerate the `build` script to include grype false-positive suppression
  and descriptor/provenance SHA synchronization updates
- Update `README.md` and `SECURITY.md` for Amazon Linux 2023 migration
- Add leading docstrings to generated build functions

## [1.1.0] - 2026-04-27

### Changed

- Migrate base image from Alpine 3.22 to Amazon Linux 2023 (AL2023); pin
  base image by digest for reproducible builds
- Replace `wget` supercronic install with `curl -fsSL` (AL2023 ships curl,
  not wget, by default)
- Replace Alpine `apk` package manager with `dnf`; add `--allowerasing`
  flag for conflict resolution
- Replace Alpine `gojq` + symlink with standard `jq` package
- Remove Alpine `py3-pip` and pip CVE patches from base image; derived
  images manage their own python toolchain
- Add `findutils`, `gnupg2`, `hostname`, `procps-ng`, `shadow-utils`, `tar`
  to base install (required by derived images)
- Bump supercronic `v0.2.44` → `v0.2.45` (ships with Go ≥ 1.26.2,
  patching CVE-2026-32280, CVE-2026-32282, CVE-2026-33810)
- Update OCI `base.name` label from `alpine` to `amazonlinux:2023`
- Add `SHELL ["/bin/bash", "-o", "pipefail", "-c"]` directive

### Fixed

- CI Trivy scan: add `ignore-unfixed: true` to suppress CVE-2026-3219
  (pip, MEDIUM, no upstream fix); align gating behavior with
  `shared-github-workflows/scan.yml`
- CI Trivy scan: pin `trivy-action` from `@master` to
  `@57a97c7e...` (v0.35.0)

### Build

- Pin `shared-github-workflows` CI reference to `@v1`
- Regenerate build script: add `dev-latest` tag to dev builds

## [1.0.1] - 2026-04-26

### Changed

- CI: replace `publish.yml` with inline push job in `ci.yml`

## [1.0.0] - 2026-04-19

### Added

- Initial release

[Unreleased]: https://github.com/1121citrus/aws-backup-base/compare/v1.1.8...HEAD
[1.1.8]: https://github.com/1121citrus/aws-backup-base/compare/v1.1.7...v1.1.8
[1.1.7]: https://github.com/1121citrus/aws-backup-base/compare/v1.1.6...v1.1.7
[1.1.6]: https://github.com/1121citrus/aws-backup-base/compare/v1.1.5...v1.1.6
[1.1.5]: https://github.com/1121citrus/aws-backup-base/compare/v1.1.4...v1.1.5
[1.1.4]: https://github.com/1121citrus/aws-backup-base/compare/v1.1.3...v1.1.4
[1.1.3]: https://github.com/1121citrus/aws-backup-base/compare/v1.1.2...v1.1.3
[1.1.2]: https://github.com/1121citrus/aws-backup-base/compare/v1.1.1...v1.1.2
[1.1.1]: https://github.com/1121citrus/aws-backup-base/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/1121citrus/aws-backup-base/compare/v1.0.1...v1.1.0
[1.0.1]: https://github.com/1121citrus/aws-backup-base/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/1121citrus/aws-backup-base/releases/tag/v1.0.0
