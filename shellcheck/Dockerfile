# syntax=docker/dockerfile:1.7

ARG BASE_IMAGE=ghcr.io/costscope/ci-base:latest
FROM ${BASE_IMAGE}

ARG SHELLCHECK_VERSION=v0.11.0

LABEL org.opencontainers.image.title="CostScope CI (shellcheck)" \
      org.opencontainers.image.description="CI image with bash + ShellCheck preinstalled for deterministic, fast lint runs" \
      org.opencontainers.image.source="https://github.com/costscope/costscope-ci-images" \
      org.opencontainers.image.licenses="Apache-2.0"

# Install ShellCheck from upstream release (static binary tarball)
RUN set -eux; \
    arch=$(uname -m); \
    case "$arch" in \
      x86_64) ARCH=x86_64 ;; \
      aarch64|arm64) ARCH=aarch64 ;; \
      *) echo "Unsupported arch: $arch" >&2; exit 1 ;; \
    esac; \
    curl -fsSL "https://github.com/koalaman/shellcheck/releases/download/${SHELLCHECK_VERSION}/shellcheck-${SHELLCHECK_VERSION}.linux.${ARCH}.tar.xz" -o /tmp/shellcheck.txz; \
    mkdir -p /tmp/sc; \
    tar -C /tmp/sc -xJf /tmp/shellcheck.txz; \
    mv /tmp/sc/shellcheck-${SHELLCHECK_VERSION}/shellcheck /usr/local/bin/shellcheck; \
    chmod +x /usr/local/bin/shellcheck; \
    rm -rf /tmp/shellcheck.txz /tmp/sc

# Verify tools present
RUN set -eu; \
    bash --version >/dev/null 2>&1 || { echo "bash missing" >&2; exit 1; }; \
    shellcheck --version >/dev/null 2>&1 || { echo "shellcheck missing" >&2; exit 1; }

WORKDIR /work

CMD ["bash", "-lc", "echo 'ShellCheck:'; shellcheck --version && echo 'Bash:' && bash --version | head -n1"]
