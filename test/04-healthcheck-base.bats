#!/usr/bin/env bats
# test/04-healthcheck-base.bats — unit tests for src/healthcheck-base functions.
#
# Each test sources only the function definitions by stopping before the
# top-level `is_healthy || exit 1` call.  This is done by appending an
# early-exit sentinel and sourcing the resulting temp file.
#
# Copyright (C) 2025-2026 James Hanlon [mailto:jim@hanlonsoftware.com]
# SPDX-License-Identifier: AGPL-3.0-or-later

REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
HEALTHCHECK_BASE="${REPO_ROOT}/src/healthcheck-base"

setup() {
    TEST_TMP="$(mktemp -d)"
    # Build a sourceable version of healthcheck-base: stop before the
    # top-level is_healthy call by inserting `return 0` just before it.
    SOURCEABLE="${TEST_TMP}/healthcheck-functions"
    sed 's/^is_healthy || exit 1/return 0/' "${HEALTHCHECK_BASE}" \
        > "${SOURCEABLE}"

    SUCCESS_FILE="${TEST_TMP}/last-success"
    STARTUP_FILE="${TEST_TMP}/startup"
    CRONTAB_FILE="${TEST_TMP}/crontab"
    COMMAND_NAME="/usr/local/bin/my-backup"
}

teardown() {
    rm -rf "${TEST_TMP}"
}

# Wrapper: source healthcheck-base functions with required env vars set.
# Usage: hc_run [extra env assignments] -- <function call>
hc_env() {
    cat <<ENV
export INCLUDE_DIR="${REPO_ROOT}/src"
export HEALTHCHECK_SUCCESS_FILE="${SUCCESS_FILE}"
export HEALTHCHECK_COMMAND_NAME="${COMMAND_NAME}"
export HEALTHCHECK_STARTUP_FILE=""
export HEALTHCHECK_CRONTAB_FILE="${CRONTAB_FILE}"
export HEALTHCHECK_MAX_AGE_SECONDS=3600
export HEALTHCHECK_STARTUP_GRACE_SECONDS=900
ENV
}

# ---------------------------------------------------------------------------
# epoch_modified
# ---------------------------------------------------------------------------

@test "epoch_modified: returns a numeric timestamp for an existing file" {
    touch "${SUCCESS_FILE}"
    run bash -c "
        $(hc_env)
        source '${SOURCEABLE}'
        result=\$(epoch_modified '${SUCCESS_FILE}')
        [[ \"\${result}\" =~ ^[0-9]+$ ]]
    "
    [ "$status" -eq 0 ]
}

@test "epoch_modified: exits non-zero for a missing file" {
    run bash -c "
        $(hc_env)
        source '${SOURCEABLE}'
        epoch_modified '${TEST_TMP}/nonexistent'
    "
    [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# has_cronjob_run
# ---------------------------------------------------------------------------

@test "has_cronjob_run: returns 0 when success file is fresh" {
    touch "${SUCCESS_FILE}"
    run bash -c "
        $(hc_env)
        source '${SOURCEABLE}'
        has_cronjob_run
    "
    [ "$status" -eq 0 ]
}

@test "has_cronjob_run: exits non-zero when success file is stale" {
    # Set mtime to a fixed past date guaranteed to exceed any max age.
    touch -t 200001010000.00 "${SUCCESS_FILE}"
    run bash -c "
        $(hc_env)
        export HEALTHCHECK_MAX_AGE_SECONDS=3600
        source '${SOURCEABLE}'
        has_cronjob_run
    "
    [ "$status" -ne 0 ]
}

@test "has_cronjob_run: returns 0 within startup grace when no success file" {
    touch "${STARTUP_FILE}"
    run bash -c "
        $(hc_env)
        export HEALTHCHECK_STARTUP_FILE='${STARTUP_FILE}'
        export HEALTHCHECK_STARTUP_GRACE_SECONDS=3600
        source '${SOURCEABLE}'
        has_cronjob_run
    "
    [ "$status" -eq 0 ]
}

@test "has_cronjob_run: exits non-zero when no success file and no startup file" {
    run bash -c "
        $(hc_env)
        source '${SOURCEABLE}'
        has_cronjob_run
    "
    [ "$status" -ne 0 ]
    [[ "${output}" == *"missing both"* ]]
}

# ---------------------------------------------------------------------------
# is_crontab_configured
# ---------------------------------------------------------------------------

@test "is_crontab_configured: returns 0 when command is in crontab" {
    echo "* * * * * ${COMMAND_NAME}" > "${CRONTAB_FILE}"
    run bash -c "
        $(hc_env)
        source '${SOURCEABLE}'
        is_crontab_configured
    "
    [ "$status" -eq 0 ]
}

@test "is_crontab_configured: exits non-zero when command is absent from crontab" {
    echo "* * * * * /usr/local/bin/other-command" > "${CRONTAB_FILE}"
    run bash -c "
        $(hc_env)
        source '${SOURCEABLE}'
        is_crontab_configured
    "
    [ "$status" -ne 0 ]
}

@test "is_crontab_configured: exits non-zero when crontab file does not exist" {
    run bash -c "
        $(hc_env)
        export HEALTHCHECK_CRONTAB_FILE='${TEST_TMP}/nonexistent'
        source '${SOURCEABLE}'
        is_crontab_configured
    "
    [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# is_supercronic_running
# ---------------------------------------------------------------------------

@test "is_supercronic_running: exits non-zero when supercronic is not running" {
    run bash -c "
        $(hc_env)
        source '${SOURCEABLE}'
        is_supercronic_running
    "
    [ "$status" -ne 0 ]
    [[ "${output}" == *"supercronic is not running"* ]]
}
