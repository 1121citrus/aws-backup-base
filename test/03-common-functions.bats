#!/usr/bin/env bats
# test/03-common-functions.bats — unit tests for src/common-functions.
#
# Copyright (C) 2025-2026 James Hanlon [mailto:jim@hanlonsoftware.com]
# SPDX-License-Identifier: AGPL-3.0-or-later

REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
COMMON_FUNCTIONS="${REPO_ROOT}/src/common-functions"

setup() {
    # shellcheck disable=SC1090
    source "${COMMON_FUNCTIONS}"
}

# ---------------------------------------------------------------------------
# is_true
# ---------------------------------------------------------------------------

@test "is_true: '1' returns 0" {
    is_true "1"
}

@test "is_true: 'true' returns 0" {
    is_true "true"
}

@test "is_true: 't' returns 0" {
    is_true "t"
}

@test "is_true: 'yes' returns 0" {
    is_true "yes"
}

@test "is_true: 'y' returns 0" {
    is_true "y"
}

@test "is_true: 'TRUE' (uppercase) returns 0" {
    is_true "TRUE"
}

@test "is_true: 'YES' (uppercase) returns 0" {
    is_true "YES"
}

@test "is_true: 'false' returns non-zero" {
    run bash -c "source '${COMMON_FUNCTIONS}'; is_true 'false'"
    [ "$status" -ne 0 ]
}

@test "is_true: '0' returns non-zero" {
    run bash -c "source '${COMMON_FUNCTIONS}'; is_true '0'"
    [ "$status" -ne 0 ]
}

@test "is_true: 'no' returns non-zero" {
    run bash -c "source '${COMMON_FUNCTIONS}'; is_true 'no'"
    [ "$status" -ne 0 ]
}

@test "is_true: empty string exits non-zero via :? guard" {
    run bash -c "source '${COMMON_FUNCTIONS}'; is_true ''"
    [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# path-append / path-prepend / path-remove
# ---------------------------------------------------------------------------

@test "path-append: adds entry to end of PATH" {
    PATH=/usr/bin:/bin
    path-append /test/dir >/dev/null
    [[ "${PATH}" == */test/dir ]]
}

@test "path-append: is idempotent (no duplicate)" {
    PATH=/usr/bin:/bin
    path-append /test/dir >/dev/null
    path-append /test/dir >/dev/null
    local count
    count=$(tr ':' '\n' <<< "${PATH}" | grep -c '^/test/dir$')
    [ "${count}" -eq 1 ]
}

@test "path-prepend: adds entry to front of PATH" {
    PATH=/usr/bin:/bin
    path-prepend /test/dir >/dev/null
    [[ "${PATH}" == /test/dir:* ]]
}

@test "path-prepend: is idempotent (no duplicate)" {
    PATH=/usr/bin:/bin
    path-prepend /test/dir >/dev/null
    path-prepend /test/dir >/dev/null
    local count
    count=$(tr ':' '\n' <<< "${PATH}" | grep -c '^/test/dir$')
    [ "${count}" -eq 1 ]
}

@test "path-remove: removes entry from PATH" {
    PATH=/usr/bin:/test/dir:/bin
    path-remove /test/dir >/dev/null
    [[ "${PATH}" != */test/dir* ]]
}

@test "path-remove: no-op when entry not in PATH" {
    PATH=/usr/bin:/bin
    path-remove /not/present >/dev/null
    [ "${PATH}" = "/usr/bin:/bin" ]
}

@test "path-remove: returns 1 for empty argument" {
    run bash -c "source '${COMMON_FUNCTIONS}'; path-remove ''"
    [ "$status" -eq 1 ]
}

# ---------------------------------------------------------------------------
# touch_healthcheck_startup_marker
# ---------------------------------------------------------------------------

@test "touch_healthcheck_startup_marker: creates the file when HEALTHCHECK_STARTUP_FILE is set" {
    local marker="${BATS_TEST_TMPDIR}/startup-marker"
    HEALTHCHECK_STARTUP_FILE="${marker}" touch_healthcheck_startup_marker
    [ -f "${marker}" ]
}

@test "touch_healthcheck_startup_marker: returns 0 when HEALTHCHECK_STARTUP_FILE is unset" {
    unset HEALTHCHECK_STARTUP_FILE
    run touch_healthcheck_startup_marker
    [ "$status" -eq 0 ]
}

@test "touch_healthcheck_startup_marker: does not create a file when HEALTHCHECK_STARTUP_FILE is unset" {
    unset HEALTHCHECK_STARTUP_FILE
    touch_healthcheck_startup_marker
    [[ ! -f "${BATS_TEST_TMPDIR}/startup-marker" ]]
}
