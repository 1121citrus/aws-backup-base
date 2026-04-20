# .github/workflows

GitHub Actions workflows for aws-backup-base.

## `ci.yml` — CI

Runs on every push to `main` or `staging`, on pull requests, and on
manual dispatch.

**Job: `lint-and-test`**

Executes `./build --no-scan --no-advise --no-push`, which runs:

1. Lint — hadolint (Dockerfile), shellcheck, markdownlint
2. Build — single-platform image loaded into the local Docker daemon
3. Test — bats suite (`01-build.bats` through `05-startup-base.bats`)
4. Smoke — built-image sanity check

**Job: `scan`** *(schedule and manual dispatch only)*

Runs on the weekly Monday 06:00 UTC schedule. Builds the image tagged
`ci-scan`, then scans with:

- Trivy (CRITICAL and HIGH; SARIF output uploaded as a 30-day artifact)
- Grype (critical severity cutoff)

Scanner DBs are cached with `actions/cache` keyed on `version.txt`.
Named Docker volumes are not used because GitHub runners are ephemeral.

## `publish.yml` — Publish

Triggered by version tags (`v*.*.*`) and manual dispatch.

1. Sets up QEMU and Buildx for cross-platform builds.
2. Authenticates to Docker Hub using the `DOCKERHUB_USERNAME` and
   `DOCKERHUB_TOKEN` repository secrets.
3. Strips the leading `v` from the tag ref to derive the version string.
4. Runs `./build --push --version <version> --platform linux/amd64,linux/arm64`.

## Required secrets

| Secret | Used by | Description |
| ------ | ------- | ----------- |
| `DOCKERHUB_USERNAME` | `publish.yml` | Docker Hub login username |
| `DOCKERHUB_TOKEN` | `publish.yml` | Docker Hub access token (read/write) |
