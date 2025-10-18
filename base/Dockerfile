# syntax=docker/dockerfile:1.7
# Base CI image for CostScope security/QA jobs
# Includes pinned versions of tools to mirror .github/workflows/security.yml

ARG BASE_IMAGE=ubuntu:24.04
FROM ${BASE_IMAGE} AS base

ARG DEBIAN_FRONTEND=noninteractive
ARG GO_VERSION=1.24.6
# Tool versions (keep aligned with workflow env defaults)
ARG SYFT_VERSION=v1.33.0
ARG COSIGN_VERSION=v2.2.4
ARG TRIVY_VERSION=0.56.2
ARG GITLEAKS_VERSION=8.18.4
ARG GOSEC_VERSION=2.21.4
ARG GOVULNCHECK_VERSION=1.1.3
ARG YQ_VERSION=v4.30.6
ARG GITCLIFF_VERSION=v2.10.1
ARG OASDIFF_REF=fc23f9bb1b54519f4f847e1724dbd0ab894e8ec8
ARG GOLANGCI_LINT_VERSION=v1.61.0
ARG NODE_MAJOR=20

# Install base deps and apply security updates
RUN set -eux; \
        apt-get update; \
        apt-get -y upgrade; \
        apt-get install -y --no-install-recommends \
            curl ca-certificates gnupg lsb-release git make jq tar gzip xz-utils rsync build-essential; \
        # Install Node.js (pinned major) for GitHub Actions node-based actions inside container jobs
        curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR}.x | bash -; \
        apt-get install -y --no-install-recommends nodejs; \
        apt-get -y autoremove; \
        apt-get clean; \
        rm -rf /var/lib/apt/lists/*

# Install Go (official tarball)
RUN curl -fsSL https://go.dev/dl/go${GO_VERSION}.linux-$(arch | sed 's/aarch64/arm64/;s/x86_64/amd64/').tar.gz -o /tmp/go.tgz \
    && rm -rf /usr/local/go \
    && tar -C /usr/local -xzf /tmp/go.tgz \
    && rm /tmp/go.tgz
# Ensure both Go and local binaries are available in PATH; force local toolchain to avoid auto-downloads
ENV PATH="/usr/local/bin:/usr/local/go/bin:${PATH}"
ENV GOTOOLCHAIN=local
# Speed up and stabilize Go module downloads during image build
ENV GOPROXY="https://proxy.golang.org,direct"

# Add installer script
COPY scripts/install-tools.sh /usr/local/bin/install-tools
RUN chmod +x /usr/local/bin/install-tools

# Install pinned tools
RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/go/pkg/mod \
    install-tools \
    --syft "${SYFT_VERSION}" \
    --cosign "${COSIGN_VERSION}" \
    --trivy "${TRIVY_VERSION}" \
    --gitleaks "${GITLEAKS_VERSION}" \
    --gosec "${GOSEC_VERSION}" \
    --govulncheck "${GOVULNCHECK_VERSION}" \
    --yq "${YQ_VERSION}" \
    --golangci-lint "${GOLANGCI_LINT_VERSION}" \
    --gitcliff "${GITCLIFF_VERSION}"

# Optionally install oasdiff at a pinned commit ref for contract checks
RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/go/pkg/mod \
    if [ -n "${OASDIFF_REF}" ]; then \
            GOBIN=/usr/local/bin go install "github.com/oasdiff/oasdiff@${OASDIFF_REF}"; \
        fi

# Verify tools
# Strictly verify critical tools are present; fail build if missing
RUN set -eu; \
    echo "Verifying toolchain..."; \
    command -v make >/dev/null 2>&1 || { echo "make not in PATH" >&2; exit 1; }; \
    make --version >/dev/null 2>&1 || { echo "make --version failed" >&2; exit 1; }; \
    syft version >/dev/null 2>&1 || { echo "syft missing" >&2; exit 1; }; \
    cosign version >/dev/null 2>&1 || { echo "cosign missing" >&2; exit 1; }; \
    trivy --version >/dev/null 2>&1 || { echo "trivy missing" >&2; exit 1; }; \
    gitleaks version >/dev/null 2>&1 || { echo "gitleaks missing" >&2; exit 1; }; \
    gosec --version >/dev/null 2>&1 || { echo "gosec missing" >&2; exit 1; }; \
    govulncheck -version >/dev/null 2>&1 || { echo "govulncheck missing" >&2; exit 1; }; \
    yq --version >/dev/null 2>&1 || { echo "yq missing" >&2; exit 1; }; \
    git-cliff --version >/dev/null 2>&1 || { echo "git-cliff missing" >&2; exit 1; }; \
    if [ -n "${OASDIFF_REF}" ]; then command -v oasdiff >/dev/null 2>&1 || { echo "oasdiff missing" >&2; exit 1; }; fi; \
    rsync --version >/dev/null 2>&1 || { echo "rsync missing" >&2; exit 1; }; \
    golangci-lint version >/dev/null 2>&1 || { echo "golangci-lint missing" >&2; exit 1; }; \
    go version >/dev/null 2>&1 || { echo "go missing" >&2; exit 1; }; \
    node --version >/dev/null 2>&1 || { echo "node missing" >&2; exit 1; }; \
    npm --version >/dev/null 2>&1 || { echo "npm missing" >&2; exit 1; }

# Useful defaults
ENV CGO_ENABLED=0

WORKDIR /work

# Default command prints versions
CMD ["bash", "-lc", "echo CI toolchain versions:; command -v make >/dev/null && make --version | head -n1 || echo 'make: not found'; syft version; cosign version; trivy --version; gitleaks version; gosec --version; govulncheck -version; yq --version; (oasdiff version || true); go version"]