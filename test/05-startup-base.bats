#!/usr/bin/env bats
# test/05-startup-base.bats — unit tests for src/startup-base.
#
# Copyright (C) 2025-2026 James Hanlon [mailto:jim@hanlonsoftware.com]
# SPDX-License-Identifier: AGPL-3.0-or-later

REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
STARTUP_BASE="${REPO_ROOT}/src/startup-base"

@test "exits non-zero when STARTUP_COMMAND is unset" {
    run env -u STARTUP_COMMAND bash "${STARTUP_BASE}"
    [ "$status" -ne 0 ]
    [[ "${output}" == *"STARTUP_COMMAND"* ]]
}

@test "passes --cron flag to the command" {
    run env STARTUP_COMMAND=echo bash "${STARTUP_BASE}"
    [ "$status" -eq 0 ]
    [[ "${output}" == *"--cron"* ]]
}

@test "passes extra arguments through after --cron" {
    run env STARTUP_COMMAND=echo bash "${STARTUP_BASE}" foo bar
    [ "$status" -eq 0 ]
    [[ "${output}" == *"--cron foo bar"* ]]
}
