#!/usr/bin/env bats
# shellcheck shell=bash
# shellcheck disable=SC2016  # single-quoted 'bash -c' strings expand in subshell
# test/06-source-coverage.bats — direct-execution coverage tests.
#
# Run source scripts directly (not via Docker) so kcov can instrument them.
# These tests complement the docker-based integration tests in 01–05 and are
# designed to exercise as many code paths as possible without network access.
#
# Coverage targets:
#   src/common-functions  (84 lines)
#   src/healthcheck-base  (107 lines)
#   src/startup-base      (28 lines — single exec line)
#
# healthcheck-base strategy: inject a mock pgrep into PATH so that
# is_supercronic_running passes; run the full script directly with varying
# env configurations to reach every branch in has_cronjob_run.

setup() {
    REPO_ROOT=$(cd "${BATS_TEST_DIRNAME}/.." && pwd)
    TEST_TMPDIR=$(mktemp -d)
    export REPO_ROOT TEST_TMPDIR
    export INCLUDE_DIR="${REPO_ROOT}/src"

    # Mock pgrep that simulates supercronic running (exit 0 always).
    mkdir -p "${TEST_TMPDIR}/bin"
    printf '#!/bin/sh\nexec /bin/true\n' > "${TEST_TMPDIR}/bin/pgrep"
    chmod +x "${TEST_TMPDIR}/bin/pgrep"
    TEST_BIN="${TEST_TMPDIR}/bin"
    export TEST_BIN

    # Shared healthcheck file paths (individual tests touch them as needed).
    HC_CRONTAB="${TEST_TMPDIR}/crontab"
    HC_SUCCESS="${TEST_TMPDIR}/last-success"
    HC_STARTUP="${TEST_TMPDIR}/startup"
    export HC_CRONTAB HC_SUCCESS HC_STARTUP
}

teardown() {
    rm -rf "${TEST_TMPDIR:-}"
}

# ── src/common-functions ──────────────────────────────────────────────────────

@test "common-functions: is_true accepts '1'" {
    run env INCLUDE_DIR="${INCLUDE_DIR}" \
        bash -c 'source "${INCLUDE_DIR}/common-functions"; is_true "1"'
    [ "$status" -eq 0 ]
}

@test "common-functions: is_true accepts 'true'" {
    run env INCLUDE_DIR="${INCLUDE_DIR}" \
        bash -c 'source "${INCLUDE_DIR}/common-functions"; is_true "true"'
    [ "$status" -eq 0 ]
}

@test "common-functions: is_true accepts 'yes'" {
    run env INCLUDE_DIR="${INCLUDE_DIR}" \
        bash -c 'source "${INCLUDE_DIR}/common-functions"; is_true "yes"'
    [ "$status" -eq 0 ]
}

@test "common-functions: is_true rejects 'false'" {
    run env INCLUDE_DIR="${INCLUDE_DIR}" \
        bash -c 'source "${INCLUDE_DIR}/common-functions"; is_true "false"'
    [ "$status" -ne 0 ]
}

@test "common-functions: is_true rejects empty string" {
    run env INCLUDE_DIR="${INCLUDE_DIR}" \
        bash -c 'source "${INCLUDE_DIR}/common-functions"; is_true ""'
    [ "$status" -ne 0 ]
}

@test "common-functions: log writes severity and message to stderr" {
    run env INCLUDE_DIR="${INCLUDE_DIR}" \
        bash -c 'source "${INCLUDE_DIR}/common-functions"; log INFO "hello log"'
    [ "$status" -eq 0 ]
    [[ "$output" == *"hello log"* ]]
}

@test "common-functions: log reads from stdin when no args" {
    run env INCLUDE_DIR="${INCLUDE_DIR}" \
        bash -c 'source "${INCLUDE_DIR}/common-functions"
                 echo "piped line" | log INFO'
    [ "$status" -eq 0 ]
    [[ "$output" == *"piped line"* ]]
}

@test "common-functions: debug writes DEBUG severity" {
    run env INCLUDE_DIR="${INCLUDE_DIR}" \
        bash -c 'source "${INCLUDE_DIR}/common-functions"; debug "dbg msg"'
    [ "$status" -eq 0 ]
    [[ "$output" == *"DEBUG"* ]]
}

@test "common-functions: info writes INFO severity" {
    run env INCLUDE_DIR="${INCLUDE_DIR}" \
        bash -c 'source "${INCLUDE_DIR}/common-functions"; info "info msg"'
    [ "$status" -eq 0 ]
    [[ "$output" == *"INFO"* ]]
}

@test "common-functions: ignore writes IGNORE severity" {
    run env INCLUDE_DIR="${INCLUDE_DIR}" \
        bash -c 'source "${INCLUDE_DIR}/common-functions"; ignore "ign msg"'
    [ "$status" -eq 0 ]
    [[ "$output" == *"IGNORE"* ]]
}

@test "common-functions: error exits non-zero and logs ERROR" {
    run env INCLUDE_DIR="${INCLUDE_DIR}" \
        bash -c 'source "${INCLUDE_DIR}/common-functions"; error "err msg"'
    [ "$status" -ne 0 ]
    [[ "$output" == *"ERROR"* ]]
    [[ "$output" == *"err msg"* ]]
}

@test "common-functions: path-append adds to end of PATH" {
    result=$(INCLUDE_DIR="${INCLUDE_DIR}" PATH=/usr/bin:/bin \
        bash -c 'source "${INCLUDE_DIR}/common-functions"; path-append /test/dir')
    [[ "${result}" == *":/test/dir" ]]
}

@test "common-functions: path-prepend adds to front of PATH" {
    result=$(INCLUDE_DIR="${INCLUDE_DIR}" PATH=/usr/bin:/bin \
        bash -c 'source "${INCLUDE_DIR}/common-functions"; path-prepend /test/dir')
    [[ "${result}" == /test/dir:* ]]
}

@test "common-functions: path-remove removes a directory" {
    result=$(INCLUDE_DIR="${INCLUDE_DIR}" PATH=/test/dir:/usr/bin:/bin \
        bash -c 'source "${INCLUDE_DIR}/common-functions"; path-remove /test/dir')
    [[ "${result}" != *"/test/dir"* ]]
    [[ "${result}" == *"/usr/bin"* ]]
}

@test "common-functions: path-remove returns 1 for empty argument" {
    run env INCLUDE_DIR="${INCLUDE_DIR}" \
        bash -c 'source "${INCLUDE_DIR}/common-functions"; path-remove ""'
    [ "$status" -eq 1 ]
}

# ── src/healthcheck-base ──────────────────────────────────────────────────────
# All tests run the script directly so kcov can attribute lines.
# Tests that need is_supercronic_running to pass inject TEST_BIN (mock pgrep)
# into PATH.  Tests for supercronic-not-running omit TEST_BIN from PATH.

@test "healthcheck-base: exits non-zero when HEALTHCHECK_SUCCESS_FILE unset" {
    run env -u HEALTHCHECK_SUCCESS_FILE \
        INCLUDE_DIR="${INCLUDE_DIR}" \
        HEALTHCHECK_COMMAND_NAME="/usr/local/bin/my-backup" \
        bash "${REPO_ROOT}/src/healthcheck-base"
    [ "$status" -ne 0 ]
}

@test "healthcheck-base: exits non-zero when HEALTHCHECK_COMMAND_NAME unset" {
    run env -u HEALTHCHECK_COMMAND_NAME \
        INCLUDE_DIR="${INCLUDE_DIR}" \
        HEALTHCHECK_SUCCESS_FILE="${HC_SUCCESS}" \
        bash "${REPO_ROOT}/src/healthcheck-base"
    [ "$status" -ne 0 ]
}

@test "healthcheck-base: exits non-zero when crontab file is absent" {
    run env \
        DEBUG=true \
        INCLUDE_DIR="${INCLUDE_DIR}" \
        PATH="${TEST_BIN}:${PATH}" \
        HEALTHCHECK_SUCCESS_FILE="${HC_SUCCESS}" \
        HEALTHCHECK_COMMAND_NAME="/usr/local/bin/my-backup" \
        HEALTHCHECK_CRONTAB_FILE="${TEST_TMPDIR}/nonexistent-crontab" \
        HEALTHCHECK_MAX_AGE_SECONDS=3600 \
        HEALTHCHECK_STARTUP_GRACE_SECONDS=900 \
        bash "${REPO_ROOT}/src/healthcheck-base"
    [ "$status" -ne 0 ]
    [[ "$output" == *"crontab"* ]]
}

@test "healthcheck-base: exits non-zero when command absent from crontab" {
    echo "* * * * * /other/command" > "${HC_CRONTAB}"
    run env \
        DEBUG=true \
        INCLUDE_DIR="${INCLUDE_DIR}" \
        PATH="${TEST_BIN}:${PATH}" \
        HEALTHCHECK_SUCCESS_FILE="${HC_SUCCESS}" \
        HEALTHCHECK_COMMAND_NAME="/usr/local/bin/my-backup" \
        HEALTHCHECK_CRONTAB_FILE="${HC_CRONTAB}" \
        HEALTHCHECK_MAX_AGE_SECONDS=3600 \
        HEALTHCHECK_STARTUP_GRACE_SECONDS=900 \
        bash "${REPO_ROOT}/src/healthcheck-base"
    [ "$status" -ne 0 ]
    [[ "$output" == *"crontab is not configured"* ]]
}

@test "healthcheck-base: exits non-zero when supercronic not running" {
    echo "* * * * * /usr/local/bin/my-backup" > "${HC_CRONTAB}"
    # Do NOT include TEST_BIN so real pgrep finds no supercronic process.
    run env \
        DEBUG=true \
        INCLUDE_DIR="${INCLUDE_DIR}" \
        HEALTHCHECK_SUCCESS_FILE="${HC_SUCCESS}" \
        HEALTHCHECK_COMMAND_NAME="/usr/local/bin/my-backup" \
        HEALTHCHECK_CRONTAB_FILE="${HC_CRONTAB}" \
        HEALTHCHECK_MAX_AGE_SECONDS=3600 \
        HEALTHCHECK_STARTUP_GRACE_SECONDS=900 \
        bash "${REPO_ROOT}/src/healthcheck-base"
    [ "$status" -ne 0 ]
    [[ "$output" == *"supercronic is not running"* ]]
}

@test "healthcheck-base: exits 0 when crontab ok, supercronic mocked, success file fresh" {
    echo "* * * * * /usr/local/bin/my-backup" > "${HC_CRONTAB}"
    touch "${HC_SUCCESS}"
    run env \
        DEBUG=true \
        INCLUDE_DIR="${INCLUDE_DIR}" \
        PATH="${TEST_BIN}:${PATH}" \
        HEALTHCHECK_SUCCESS_FILE="${HC_SUCCESS}" \
        HEALTHCHECK_COMMAND_NAME="/usr/local/bin/my-backup" \
        HEALTHCHECK_CRONTAB_FILE="${HC_CRONTAB}" \
        HEALTHCHECK_MAX_AGE_SECONDS=3600 \
        HEALTHCHECK_STARTUP_GRACE_SECONDS=900 \
        bash "${REPO_ROOT}/src/healthcheck-base"
    [ "$status" -eq 0 ]
}

@test "healthcheck-base: exits 0 when within startup grace and no success file" {
    echo "* * * * * /usr/local/bin/my-backup" > "${HC_CRONTAB}"
    touch "${HC_STARTUP}"
    run env \
        DEBUG=true \
        INCLUDE_DIR="${INCLUDE_DIR}" \
        PATH="${TEST_BIN}:${PATH}" \
        HEALTHCHECK_SUCCESS_FILE="${HC_SUCCESS}" \
        HEALTHCHECK_COMMAND_NAME="/usr/local/bin/my-backup" \
        HEALTHCHECK_CRONTAB_FILE="${HC_CRONTAB}" \
        HEALTHCHECK_STARTUP_FILE="${HC_STARTUP}" \
        HEALTHCHECK_MAX_AGE_SECONDS=3600 \
        HEALTHCHECK_STARTUP_GRACE_SECONDS=3600 \
        bash "${REPO_ROOT}/src/healthcheck-base"
    [ "$status" -eq 0 ]
}

@test "healthcheck-base: exits non-zero when success file is stale" {
    echo "* * * * * /usr/local/bin/my-backup" > "${HC_CRONTAB}"
    touch -t 200001010000.00 "${HC_SUCCESS}"
    run env \
        DEBUG=true \
        INCLUDE_DIR="${INCLUDE_DIR}" \
        PATH="${TEST_BIN}:${PATH}" \
        HEALTHCHECK_SUCCESS_FILE="${HC_SUCCESS}" \
        HEALTHCHECK_COMMAND_NAME="/usr/local/bin/my-backup" \
        HEALTHCHECK_CRONTAB_FILE="${HC_CRONTAB}" \
        HEALTHCHECK_MAX_AGE_SECONDS=1 \
        HEALTHCHECK_STARTUP_GRACE_SECONDS=1 \
        bash "${REPO_ROOT}/src/healthcheck-base"
    [ "$status" -ne 0 ]
    [[ "$output" == *"too old"* ]]
}

@test "healthcheck-base: exits non-zero when startup grace exceeded" {
    echo "* * * * * /usr/local/bin/my-backup" > "${HC_CRONTAB}"
    touch -t 200001010000.00 "${HC_STARTUP}"
    run env \
        DEBUG=true \
        INCLUDE_DIR="${INCLUDE_DIR}" \
        PATH="${TEST_BIN}:${PATH}" \
        HEALTHCHECK_SUCCESS_FILE="${HC_SUCCESS}" \
        HEALTHCHECK_COMMAND_NAME="/usr/local/bin/my-backup" \
        HEALTHCHECK_CRONTAB_FILE="${HC_CRONTAB}" \
        HEALTHCHECK_STARTUP_FILE="${HC_STARTUP}" \
        HEALTHCHECK_MAX_AGE_SECONDS=1 \
        HEALTHCHECK_STARTUP_GRACE_SECONDS=1 \
        bash "${REPO_ROOT}/src/healthcheck-base"
    [ "$status" -ne 0 ]
    [[ "$output" == *"grace period exceeded"* ]]
}

@test "healthcheck-base: exits non-zero when no success and no startup markers" {
    echo "* * * * * /usr/local/bin/my-backup" > "${HC_CRONTAB}"
    run env \
        DEBUG=true \
        INCLUDE_DIR="${INCLUDE_DIR}" \
        PATH="${TEST_BIN}:${PATH}" \
        HEALTHCHECK_SUCCESS_FILE="${HC_SUCCESS}" \
        HEALTHCHECK_COMMAND_NAME="/usr/local/bin/my-backup" \
        HEALTHCHECK_CRONTAB_FILE="${HC_CRONTAB}" \
        HEALTHCHECK_MAX_AGE_SECONDS=3600 \
        HEALTHCHECK_STARTUP_GRACE_SECONDS=900 \
        bash "${REPO_ROOT}/src/healthcheck-base"
    [ "$status" -ne 0 ]
    [[ "$output" == *"missing both"* ]]
}

# ── src/startup-base ──────────────────────────────────────────────────────────

@test "startup-base: exits non-zero when STARTUP_COMMAND is unset" {
    run env -u STARTUP_COMMAND bash "${REPO_ROOT}/src/startup-base"
    [ "$status" -ne 0 ]
    [[ "$output" == *"STARTUP_COMMAND"* ]]
}

@test "startup-base: passes --cron to STARTUP_COMMAND" {
    run env STARTUP_COMMAND=echo bash "${REPO_ROOT}/src/startup-base"
    [ "$status" -eq 0 ]
    [[ "$output" == *"--cron"* ]]
}

@test "startup-base: passes extra arguments after --cron" {
    run env STARTUP_COMMAND=echo bash "${REPO_ROOT}/src/startup-base" foo bar
    [ "$status" -eq 0 ]
    [[ "$output" == *"--cron foo bar"* ]]
}
