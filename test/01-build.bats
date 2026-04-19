#!/usr/bin/env bats
# test/01-build.bats — verify build script CLI option coverage.
#
# Tests that key options are recognized and produce the expected output in
# --dry-run mode; no Docker images are built or pulled.
#
# Copyright (C) 2025-2026 James Hanlon [mailto:jim@hanlonsoftware.com]
# SPDX-License-Identifier: AGPL-3.0-or-later

setup() {
    REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    BUILD="${REPO_ROOT}/build"
}

@test "build --help lists --advice option" {
    local output
    output=$("${BUILD}" --help 2>&1)
    echo "output: ${output}"
    [[ "${output}" == *"--advice"* ]]
}

@test "build --help lists --cache option" {
    local output
    output=$("${BUILD}" --help 2>&1)
    echo "output: ${output}"
    [[ "${output}" == *"--cache CACHE_RULES"* ]]
}

@test "build --advice scout is rejected (Scout is gating)" {
    local output
    output=$("${BUILD}" --advice scout 2>&1) || true
    echo "output: ${output}"
    [[ "${output}" == *"Unknown advisement"* ]]
}

@test "build --advise Dive enables Dive advisement stage" {
    run "${BUILD}" --advise Dive --dry-run --no-lint --no-test --no-scan
    echo "output: ${output}"
    [[ "${output}" == *"Stage 5c: Advise (Dive)"* ]]
}

@test "build --advise DIVE enables Dive advisement stage" {
    run "${BUILD}" --advise DIVE --dry-run --no-lint --no-test --no-scan
    echo "output: ${output}"
    [[ "${output}" == *"Stage 5c: Advise (Dive)"* ]]
}

@test "build --cache reset=all resets Trivy DB" {
    local output
    output=$("${BUILD}" --cache "reset=all" --dry-run --no-lint --no-test --no-scan --no-advise 2>&1)
    echo "output: ${output}"
    [[ "${output}" == *"Cache: reset Trivy DB"* ]]
}

@test "build --cache reset=all resets Grype DB" {
    local output
    output=$("${BUILD}" --cache "reset=all" --dry-run --no-lint --no-test --no-scan --no-advise 2>&1)
    echo "output: ${output}"
    [[ "${output}" == *"Cache: reset Grype DB"* ]]
}

@test "build --cache skip-update=all skips Trivy DB update" {
    local output
    output=$("${BUILD}" --cache "skip-update=all" --dry-run --no-lint --no-test 2>&1)
    echo "output: ${output}"
    [[ "${output}" == *"Trivy DB update skipped"* ]]
}

@test "build --cache Reset=All resets both caches" {
    local output
    output=$("${BUILD}" --cache "Reset=All" --dry-run --no-lint --no-test --no-scan --no-advise 2>&1)
    echo "output: ${output}"
    [[ "${output}" == *"Cache: reset Trivy DB"* ]]
    [[ "${output}" == *"Cache: reset Grype DB"* ]]
}

@test "build --cache Skip-Update=TrIvY skips Trivy DB update" {
    run "${BUILD}" --cache "Skip-Update=TrIvY" --dry-run --no-lint --no-test
    [ "$status" -eq 0 ]
    echo "output: ${output}"
    [[ "${output}" == *"Trivy DB update skipped"* ]]
}

@test "build includes smoke stage by default in dry-run" {
    run "${BUILD}" --dry-run --no-lint --no-test --no-scan --no-advise
    echo "output: ${output}"
    [[ "${output}" == *"Stage 3b: Smoke"* ]]
}

@test "build --no-smoke disables smoke stage" {
    run "${BUILD}" --no-smoke --dry-run --no-lint --no-test --no-scan --no-advise
    echo "output: ${output}"
    [[ "${output}" != *"Stage 3b: Smoke"* ]]
}
