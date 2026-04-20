# aws-backup-base

Shared Alpine + AWS CLI + supercronic base image for 1121 Citrus Avenue backup
services.

## Purpose

Provides a common foundation for cron-based AWS backup services:

- Alpine 3.22
- AWS CLI >= 2.20
- supercronic v0.2.44 (compiled from source with Go 1.26.2 for CVE patches)
- bash >= 5.2, coreutils, jq
- `/usr/local/include/common-functions` — shared bash utilities
- `/usr/local/bin/healthcheck-base` — configurable generic healthcheck
- `/usr/local/bin/startup-base` — generic startup shim

## Usage

Child images build on this base:

```dockerfile
FROM 1121citrus/aws-backup-base:0.1.0

# Install application-specific packages
RUN apk add --no-cache ...

# Copy application scripts
COPY --chmod=755 ./src/my-backup /usr/local/bin/

# Create non-privileged user
ARG UID=10001
RUN adduser --disabled-password --gecos "" --shell "/sbin/nologin" \
        --uid "${UID}" my-backup \
    && install -d -m 0755 -o my-backup /var/spool/cron/crontabs

USER my-backup

ENV HEALTHCHECK_SUCCESS_FILE=/tmp/my-backup.last-success
ENV HEALTHCHECK_COMMAND_NAME=/usr/local/bin/my-backup
HEALTHCHECK --interval=60s --timeout=5s --retries=3 \
    CMD ["/usr/local/bin/healthcheck-base"]

CMD ["/usr/local/bin/my-backup", "--cron"]
```

## `healthcheck-base` environment variables

| Variable                          | Req | Default               |
| --------------------------------- | --- | --------------------- |
| `HEALTHCHECK_SUCCESS_FILE`        | yes | —                     |
| `HEALTHCHECK_COMMAND_NAME`        | yes | —                     |
| `HEALTHCHECK_MAX_AGE_SECONDS`     | no  | `172800`              |
| `HEALTHCHECK_STARTUP_GRACE_SECONDS` | no | `900`               |
| `HEALTHCHECK_STARTUP_FILE`        | no  | —                     |
| `HEALTHCHECK_CRONTAB_FILE`        | no  | crontabs/\<username\> |

- `HEALTHCHECK_SUCCESS_FILE` — path to the success marker file
- `HEALTHCHECK_COMMAND_NAME` — binary path grepped in the crontab file
- `HEALTHCHECK_MAX_AGE_SECONDS` — maximum backup age before unhealthy
- `HEALTHCHECK_STARTUP_GRACE_SECONDS` — startup grace period
- `HEALTHCHECK_STARTUP_FILE` — startup marker file (skipped if unset)
- `HEALTHCHECK_CRONTAB_FILE` — defaults to `/var/spool/cron/crontabs/<user>`

## `startup-base` environment variables

| Variable         | Required | Description                                    |
| ---------------- | -------- | ---------------------------------------------- |
| `STARTUP_COMMAND` | yes     | Application binary to exec with `--cron`       |

## Development

Run `./build` locally to lint, build, test, and scan before pushing.

```sh
./build              # full pipeline: lint → build → test → smoke → scan
./build --no-scan    # skip vulnerability scans for fast iteration
./build --dry-run    # print each command without executing
./build --help       # full option reference
```

## License

AGPL-3.0-or-later — see [LICENSE.md](LICENSE.md).
