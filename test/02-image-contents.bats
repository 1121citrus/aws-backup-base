#!/usr/bin/env bats
# test/02-image-contents.bats — verify the aws-backup-base image contains expected tooling.
#
# Requires IMAGE to be set in the environment (done by bats-docker-cli test mode).
#
# Copyright (C) 2025-2026 James Hanlon [mailto:jim@hanlonsoftware.com]
# SPDX-License-Identifier: AGPL-3.0-or-later

setup() {
    : "${IMAGE:?IMAGE must be set}"
}

@test "aws-cli is installed and responds to --version" {
    run docker run --rm "${IMAGE}" aws --version
    [ "$status" -eq 0 ]
    echo "output: ${output}"
    [[ "${output}" == *"aws-cli"* ]]
}

@test "supercronic is installed and executable" {
    run docker run --rm "${IMAGE}" test -x /usr/local/bin/supercronic
    [ "$status" -eq 0 ]
}

@test "bash is installed and version >= 5" {
    run docker run --rm "${IMAGE}" bash -c 'bash --version | head -1'
    [ "$status" -eq 0 ]
    echo "output: ${output}"
    [[ "${output}" == *"version 5"* ]]
}

@test "jq is installed" {
    run docker run --rm "${IMAGE}" jq --version
    [ "$status" -eq 0 ]
    echo "output: ${output}"
    [[ "${output}" == *"jq"* ]]
}

@test "healthcheck-base is executable" {
    run docker run --rm "${IMAGE}" test -x /usr/local/bin/healthcheck-base
    [ "$status" -eq 0 ]
}

@test "startup-base is executable" {
    run docker run --rm "${IMAGE}" test -x /usr/local/bin/startup-base
    [ "$status" -eq 0 ]
}

@test "common-functions is installed and readable" {
    run docker run --rm "${IMAGE}" test -r /usr/local/include/common-functions
    [ "$status" -eq 0 ]
}

@test "common-functions defines is_true function" {
    run docker run --rm "${IMAGE}" bash -c \
        'source /usr/local/include/common-functions && type is_true'
    [ "$status" -eq 0 ]
    echo "output: ${output}"
    [[ "${output}" == *"is_true is a function"* ]]
}
