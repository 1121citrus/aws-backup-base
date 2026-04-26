# syntax=docker/dockerfile:1

# Shared Alpine + AWS CLI + supercronic base image for 1121 Citrus Avenue backup services.
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
# Alpine 3.22
ARG ALPINE_IMAGE_DIGEST=sha256:55ae5d250caebc548793f321534bc6a8ef1d116f334f18f4ada1b2daad3251b2
# renovate: datasource=github-releases depName=aptible/supercronic
ARG SUPERCRONIC_VERSION=v0.2.45

ARG VERSION=dev

# hadolint ignore=DL3006
FROM alpine@${ALPINE_IMAGE_DIGEST}

# Re-declare build args after FROM so they are visible in the build stage.
ARG VERSION
ENV VERSION=${VERSION}

ARG ALPINE_IMAGE_DIGEST
ENV ALPINE_IMAGE_DIGEST=${ALPINE_IMAGE_DIGEST}

ARG SUPERCRONIC_VERSION
ENV SUPERCRONIC_VERSION=${SUPERCRONIC_VERSION}

ARG BUILD_DATE=unknown
ENV BUILD_DATE=${BUILD_DATE}

ARG GIT_COMMIT=unknown
ENV GIT_COMMIT=${GIT_COMMIT}

# OCI image annotations (https://github.com/opencontainers/image-spec/blob/main/annotations.md)
LABEL org.opencontainers.image.title="aws-backup-base" \
      org.opencontainers.image.description="Shared Alpine + AWS CLI + supercronic base for 1121 Citrus Avenue backup services" \
      org.opencontainers.image.url="https://github.com/1121citrus/aws-backup-base" \
      org.opencontainers.image.source="https://github.com/1121citrus/aws-backup-base" \
      org.opencontainers.image.vendor="1121 Citrus Avenue" \
      org.opencontainers.image.authors="1121-citrus <1121-citrus@gmail.com>" \
      org.opencontainers.image.licenses="AGPL-3.0-or-later" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${GIT_COMMIT}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.base.name="alpine" \
      org.opencontainers.image.base.digest="${ALPINE_IMAGE_DIGEST}"

# Install runtime dependencies and supercronic.
# DL3018: version constraints use '>' (minimum) rather than '=' (exact) by
# design — apk does not have a lock-file mechanism and exact pins would break
# on every Alpine point release.
# hadolint ignore=DL3018,DL4006
RUN set -eux; \
    apk update && \
    apk upgrade --no-cache --no-interactive && \
    apk add --no-cache --no-interactive --upgrade \
        'aws-cli>2.20' \
        'bash>5.2' \
        'coreutils>9' \
        'gojq' \
        'py3-pip>23.0' \
    && ln -sf /usr/bin/gojq /usr/local/bin/jq \
    && SUPERCRONIC_ARCH="$(uname -m \
            | sed 's/x86_64/amd64/;s/aarch64/arm64/')" \
    && wget -qO /usr/local/bin/supercronic \
            "https://github.com/aptible/supercronic/releases/download/${SUPERCRONIC_VERSION}/supercronic-linux-${SUPERCRONIC_ARCH}" \
    && chmod 0755 /usr/local/bin/supercronic \
    && pip3 install --no-cache-dir --break-system-packages \
        'cryptography>=46.0.5' \
        'pip>=25.3' \
        'urllib3>=2.6.3' \
        'wheel>=0.46.2' \
        'zipp>=3.19.1' \
    && install -d -m 755 /usr/local/include \
    && echo "[INFO] completed installing aws-backup-base"

COPY --chmod=644 ./src/common-functions /usr/local/include/
COPY --chmod=755 ./src/healthcheck-base ./src/startup-base /usr/local/bin/

# No USER or CMD — child images set the non-privileged user and application
# entrypoint appropriate for their service.
WORKDIR /
