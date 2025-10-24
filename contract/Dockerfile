# syntax=docker/dockerfile:1.7

ARG BASE_IMAGE=ghcr.io/costscope/ci-base:latest
# Base image is provided via build-arg to support local dev builds without registry pulls.
FROM ${BASE_IMAGE} AS warm

# Warm Go module and build caches using the repository's go.mod/go.sum
# The build context MUST be the repository root so these COPY paths resolve.
WORKDIR /tmp/app

# Root module (primary)
COPY go.mod go.sum ./
RUN mkdir -p /root/go/pkg/mod /root/.cache/go-build
RUN --mount=type=cache,target=/root/.cache/go-build \
    GOMODCACHE=/root/go/pkg/mod go mod download -modcacherw -x >/dev/null 2>&1 || true

# Optionally warm nested tool module if present (silently skip when absent)
# Mount the entire context read-only and conditionally run if the nested path exists.
RUN --mount=type=bind,source=.,target=/src,ro \
    --mount=type=cache,target=/root/.cache/go-build \
    bash -lc 'if [ -f /src/scripts/tools/funcdups/go.mod ]; then cd /src/scripts/tools/funcdups && GOMODCACHE=/root/go/pkg/mod go mod download -modcacherw -x >/dev/null 2>&1 || true; else echo "skip: no nested funcdups module"; fi'

# Final image includes warmed caches on top of the base toolchain
FROM ${BASE_IMAGE}
LABEL org.opencontainers.image.title="CostScope CI (contract-warmed)" \
      org.opencontainers.image.description="CI image derived from ci-base with pre-fetched Go modules for faster runs"

# Ensure destinations exist then copy warmed caches
RUN mkdir -p /root/go/pkg/mod /root/.cache/go-build
COPY --from=warm /root/go/pkg/mod /root/go/pkg/mod


WORKDIR /work
CMD ["bash", "-lc", "echo Warmed Go caches present; go version && ls -ld /root/go/pkg/mod /root/.cache/go-build || true"]
