# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.1] - 2026-04-26

### Fixed

- CI Trivy scan: add `ignore-unfixed: true` to suppress CVE-2026-3219
  (pip, MEDIUM, no upstream fix); align gating behavior with
  `shared-github-workflows/scan.yml`
- CI Trivy scan: pin `trivy-action` from `@master` to
  `@57a97c7e...` (v0.35.0)

## [0.1.0] - 2026-04-19

### Added

- Initial release

[Unreleased]: https://github.com/1121citrus/aws-backup-base/compare/v0.1.1...HEAD
[0.1.1]: https://github.com/1121citrus/aws-backup-base/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/1121citrus/aws-backup-base/releases/tag/v0.1.0
