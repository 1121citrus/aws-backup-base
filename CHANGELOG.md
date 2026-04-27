# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/1121citrus/aws-backup-base/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/1121citrus/aws-backup-base/compare/v1.0.1...v1.1.0
[1.0.1]: https://github.com/1121citrus/aws-backup-base/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/1121citrus/aws-backup-base/releases/tag/v1.0.0
