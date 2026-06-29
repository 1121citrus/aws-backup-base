# aws-backup-base

Shared Alpine + AWS CLI + supercronic base Docker image for cron-based
AWS backup services. See `README.md` for usage and environment variables.

## Repository layout

- `Dockerfile` — multi-stage build; compiles supercronic from source to
  patch Go CVEs before the upstream release catches up
- `src/common-functions` — shared bash utilities (logging, PATH helpers)
- `src/healthcheck-base` — environment-driven Docker healthcheck script
- `src/startup-base` — legacy entrypoint shim
- `test/` — bats test suite; `01` and `02` require a built image;
  `03`–`05` run on the host against `src/` directly
- `build` — local CI equivalent (lint → build → test → smoke → scan → push)

## Development workflow

Run `./build` before pushing. Use `./build --help` for the full option
reference. The `build` script is the single source of truth for build
logic; the GitHub Actions workflows delegate to it.

## Coding standards

- Bash: shellcheck-clean, 4-space indent, long options, `${}` var refs
- Lines ≤ 80 characters where possible, hard limit 120
- No trailing whitespace; spaces not tabs

## Development toolchain

The project requires only `docker`, `bash`, and POSIX core utilities.
No additional tools need to be installed — `./build` encapsulates every
`docker run` invocation needed to lint, build, test, and scan.

- Use `./build` for all CI operations.
- Do not run `brew install`, `apt install`, `apk add`, or any other host
  package manager to obtain tools; use the `docker run` patterns in
  `build` instead.
- Do not search `PATH` or well-known system locations for tools not
  already in `build`; propose adding a `docker run` invocation following
  the existing pattern.
