# aws-backup-base

Shared Amazon Linux 2023 + AWS CLI + supercronic base image for 1121 Citrus
Avenue backup services.

## Purpose

Provides a common foundation for cron-based AWS backup services:

- Amazon Linux 2023 (digest-pinned)
- AWS CLI 2 (`awscli-2` from AL2023 dnf)
- supercronic v0.2.47 (compiled from source with pinned Go toolchain)
- `findutils`, `gnupg2`, `hostname`, `jq`, `procps-ng`, `shadow-utils`, `tar`
- `/usr/local/include/common-functions` — shared bash utilities
- `/usr/local/bin/healthcheck-base` — configurable generic healthcheck
- `/usr/local/bin/startup-base` — generic startup shim

## Usage

Child images build on this base:

```dockerfile
FROM 1121citrus/aws-backup-base:1.1.2

# Install application-specific packages (AL2023 uses dnf, not apk)
RUN dnf install -y --quiet --allowerasing <package> && dnf clean all

# Copy application scripts
COPY --chmod=755 ./src/my-backup /usr/local/bin/

# Create non-privileged user
ARG UID=10001
RUN useradd --no-create-home --shell /sbin/nologin --uid "${UID}" my-backup \
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

Setting `HEALTHCHECK_STARTUP_FILE` only *enables* the grace-period check —
it does not create the marker. The derivative image's own scheduler-mode
entry point (its `--cron` handler) must call
`touch_healthcheck_startup_marker` (from `common-functions`, sourced
already) once at startup, before installing the crontab:

```bash
source /usr/local/include/common-functions

function run_scheduler() {
    # ... write env file, install crontab ...
    touch_healthcheck_startup_marker
    run_once_before_schedule /usr/local/bin/my-backup
    exec supercronic "${crontab_file}"
}
```

Without the `touch_healthcheck_startup_marker` call, `HEALTHCHECK_STARTUP_FILE`
is set but the file never exists, so the grace-period branch in
`has_cronjob_run()` is dead code: every fresh deployment reports
unhealthy until the first scheduled backup completes.

That grace period is still only `HEALTHCHECK_STARTUP_GRACE_SECONDS`
(default 900s) long. For a schedule less frequent than that —
`@daily`, `*/8 hours` — the grace period expires long before the first
real run, and the container flips unhealthy anyway. Call
`run_once_before_schedule COMMAND [ARGS...]` right before the
`exec supercronic` hand-off to run the backup once for real: it writes
a genuine `HEALTHCHECK_SUCCESS_FILE` marker within minutes of startup,
independent of how far away the next scheduled run is. A failure here
is logged but does not block scheduler mode — the regular schedule
still gets its own future attempts.

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
