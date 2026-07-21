# syntax=docker/dockerfile:1

# Shared Amazon Linux 2023 + AWS CLI + supercronic base image for
# 1121 Citrus Avenue backup services.
#
# Copyright (C) 2025-2026 James Hanlon [mailto:jim@hanlonsoftware.com]
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

# Global ARGs — available to all FROM directives.
# Amazon Linux 2023 (updated 2026-07-21)
ARG AL2023_IMAGE_DIGEST=sha256:0c74e9fbba754003cfa179fd5cc65be7790d7248443276948704b8a858b298e5
# renovate: datasource=github-releases depName=aptible/supercronic
ARG SUPERCRONIC_VERSION=v0.2.47
# renovate: datasource=docker depName=golang
ARG SUPERCRONIC_BUILDER_IMAGE=golang:1.26.5-alpine

ARG VERSION=dev

# hadolint ignore=DL3006
FROM ${SUPERCRONIC_BUILDER_IMAGE} AS supercronic-builder

ARG SUPERCRONIC_VERSION

RUN GOTOOLCHAIN=go1.26.5 CGO_ENABLED=0 go install github.com/aptible/supercronic@${SUPERCRONIC_VERSION}

# hadolint ignore=DL3006
FROM amazonlinux:2023@${AL2023_IMAGE_DIGEST}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Re-declare build args after FROM so they are visible in the build stage.
ARG VERSION
ENV VERSION=${VERSION}

ARG AL2023_IMAGE_DIGEST
ENV AL2023_IMAGE_DIGEST=${AL2023_IMAGE_DIGEST}

ARG SUPERCRONIC_VERSION
ENV SUPERCRONIC_VERSION=${SUPERCRONIC_VERSION}

ARG BUILD_DATE=unknown
ENV BUILD_DATE=${BUILD_DATE}

ARG GIT_COMMIT=unknown
ENV GIT_COMMIT=${GIT_COMMIT}

# OCI image annotations (https://github.com/opencontainers/image-spec/blob/main/annotations.md)
LABEL org.opencontainers.image.title="aws-backup-base" \
      org.opencontainers.image.description="Shared Amazon Linux 2023 + AWS CLI + supercronic base for 1121 Citrus Avenue backup services" \
      org.opencontainers.image.url="https://github.com/1121citrus/aws-backup-base" \
      org.opencontainers.image.source="https://github.com/1121citrus/aws-backup-base" \
      org.opencontainers.image.vendor="1121 Citrus Avenue" \
      org.opencontainers.image.authors="1121-citrus <1121-citrus@gmail.com>" \
      org.opencontainers.image.licenses="AGPL-3.0-or-later" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${GIT_COMMIT}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.base.name="amazonlinux:2023" \
      org.opencontainers.image.base.digest="${AL2023_IMAGE_DIGEST}"

COPY --from=supercronic-builder --chmod=755 /go/bin/supercronic /usr/local/bin/supercronic

# Install runtime dependencies and supercronic.
# DL3041: version constraints omitted — AL2023 repo pins are stable and exact
# versions would break on every AL2023 point release.
# hadolint ignore=DL3041
RUN set -eux; \
    dnf upgrade -y --quiet && \
    dnf install -y --quiet --allowerasing \
        awscli-2 \
        findutils \
        gnupg2 \
        hostname \
        jq \
        procps-ng \
        shadow-utils \
        tar \
    && install -d -m 755 /usr/local/include \
    && dnf clean all \
    && rm -rf /var/cache/dnf \
    && echo "[INFO] completed installing aws-backup-base"

COPY --chmod=644 ./include/ /usr/local/include/
COPY --chmod=644 ./src/common-functions /usr/local/include/
COPY --chmod=755 ./src/healthcheck-base ./src/startup-base /usr/local/bin/

# No USER or CMD — child images set the non-privileged user and application
# entrypoint appropriate for their service.
WORKDIR /
