# src

Source scripts installed into the Docker image at build time.

## Files

### `common-functions`

Installed to `/usr/local/include/common-functions`. Sourced by
`healthcheck-base` and by child-image scripts that need shared utilities.

| Function | Description |
| -------- | ----------- |
| `log SEVERITY [message]` | Write a timestamped log line to stderr. Reads from stdin when called with no message. |
| `debug [message]` | Shorthand for `log DEBUG`. |
| `info [message]` | Shorthand for `log INFO`. |
| `error [message]` | Shorthand for `log ERROR`; exits with `$EXIT_CODE` (default 1). |
| `ignore [message]` | Shorthand for `log IGNORE`; does not exit. |
| `is_true VALUE` | Returns 0 if `VALUE` is one of `1`, `true`, `t`, `yes`, `y` (case-insensitive). |
| `path-append DIR` | Append `DIR` to `PATH`; idempotent. Prints the new `PATH`. |
| `path-prepend DIR` | Prepend `DIR` to `PATH`; idempotent. Prints the new `PATH`. |
| `path-remove DIR` | Remove all occurrences of `DIR` from `PATH`. Prints the new `PATH`. Returns 1 if `DIR` is empty. |

### `healthcheck-base`

Installed to `/usr/local/bin/healthcheck-base`. Used as the Docker
`HEALTHCHECK CMD` in child images. All behavior is driven by environment
variables — no flags.

The script calls `is_healthy` on every invocation, which runs three checks
in order:

1. `is_crontab_configured` — the crontab file exists and contains
   `HEALTHCHECK_COMMAND_NAME`.
2. `is_supercronic_running` — a `supercronic` process is alive.
3. `has_cronjob_run` — the success marker file exists and is fresh, or the
   container is still within its startup grace period.

Exits 0 (healthy) or 1 (unhealthy). See `README.md` for the full list of
environment variables.

### `startup-base`

Installed to `/usr/local/bin/startup-base`. A legacy entrypoint shim
retained for deployments that set:

```yaml
entrypoint: /usr/local/bin/startup-base
```

Execs `$STARTUP_COMMAND --cron "$@"`. New deployments should use the
application binary directly with `--cron`.
