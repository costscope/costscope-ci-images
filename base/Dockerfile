# syntax=docker/dockerfile:1.7
# Base CI image for CostScope security/QA jobs
# Includes pinned versions of tools to mirror .github/workflows/security.yml

ARG BASE_IMAGE=ubuntu:22.04
FROM ${BASE_IMAGE} AS base

ARG DEBIAN_FRONTEND=noninteractive
ARG GO_VERSION=1.24.3
# Tool versions (keep aligned with workflow env defaults)
ARG SYFT_VERSION=v1.18.0
ARG COSIGN_VERSION=v2.2.4
ARG TRIVY_VERSION=0.56.2
ARG GITLEAKS_VERSION=8.18.4
ARG GOSEC_VERSION=2.21.4
ARG GOVULNCHECK_VERSION=1.1.3

# Install base deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates gnupg lsb-release git make jq tar gzip xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Install Go (official tarball)
RUN curl -fsSL https://go.dev/dl/go${GO_VERSION}.linux-$(arch | sed 's/aarch64/arm64/;s/x86_64/amd64/').tar.gz -o /tmp/go.tgz \
    && rm -rf /usr/local/go \
    && tar -C /usr/local -xzf /tmp/go.tgz \
    && rm /tmp/go.tgz
ENV PATH="/usr/local/go/bin:${PATH}"

# Add installer script
COPY scripts/install-tools.sh /usr/local/bin/install-tools
RUN chmod +x /usr/local/bin/install-tools

# Install pinned tools
RUN install-tools \
    --syft "${SYFT_VERSION}" \
    --cosign "${COSIGN_VERSION}" \
    --trivy "${TRIVY_VERSION}" \
    --gitleaks "${GITLEAKS_VERSION}" \
    --gosec "${GOSEC_VERSION}" \
    --govulncheck "${GOVULNCHECK_VERSION}"

# Verify tools
RUN syft version && cosign version && trivy --version && gitleaks version && gosec --version && govulncheck -version && go version

# Useful defaults
ENV CGO_ENABLED=0

WORKDIR /work

# Default command prints versions
CMD ["bash", "-lc", "echo CI toolchain versions:; syft version; cosign version; trivy --version; gitleaks version; gosec --version; govulncheck -version; go version"]