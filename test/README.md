# test

Bats test suite for aws-backup-base.

## Structure

| File | Requires built image | What it tests |
| ---- | -------------------- | ------------- |
| `01-build.bats` | no | `build` script CLI option parsing in `--dry-run` mode |
| `02-image-contents.bats` | yes | Tooling present and functional inside the built image |
| `03-common-functions.bats` | no | `src/common-functions` — `is_true` and PATH helpers |
| `04-healthcheck-base.bats` | no | `src/healthcheck-base` — all functions in isolation |
| `05-startup-base.bats` | no | `src/startup-base` — argument forwarding and env guard |

Tests `01`, `03`, `04`, and `05` run on the host against the source files
directly and need only bash and bats. Test `02` requires the `IMAGE`
environment variable to be set to a built image reference.

## Running the tests

The `build` script runs the full suite automatically:

```sh
./build --no-scan --no-advise
```

To run individual files during development:

```sh
bats test/01-build.bats
bats test/03-common-functions.bats test/04-healthcheck-base.bats test/05-startup-base.bats
```

Test `02` is run by the build script after the image is built. To run it
manually, build the image first and set `IMAGE`:

```sh
IMAGE=1121citrus/aws-backup-base:dev bats test/02-image-contents.bats
```

## Test design notes

`04-healthcheck-base.bats` sources `healthcheck-base` via a pre-processed
copy that replaces the top-level `is_healthy || exit 1` call with
`return 0`. This allows each function to be tested in isolation without
triggering the healthcheck exit. The pre-processing is done with `sed` in
`setup` and written to `$BATS_TMPDIR`; the original source file is never
modified.
