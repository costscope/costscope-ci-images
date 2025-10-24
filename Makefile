REGISTRY_NS ?= ghcr.io/costscope
BASE_IMAGE_NAME ?= $(REGISTRY_NS)/ci-base
CONTRACT_IMAGE_NAME ?= $(REGISTRY_NS)/ci-contract
SHELLCHECK_IMAGE_NAME ?= $(REGISTRY_NS)/ci-shellcheck
DATE_TAG := $(shell date -u +%Y%m%d)
GIT_SHA := $(shell git rev-parse --short=12 HEAD 2>/dev/null || echo dev)
TAG ?= $(DATE_TAG)-$(GIT_SHA)
# Detect the local docker server platform for safe --load builds (falls back to linux/amd64)
LOCAL_PLATFORM := $(shell docker version -f '{{.Server.Os}}/{{.Server.Arch}}' 2>/dev/null || echo linux/amd64)
# Default local build platform (safe with --load)
PLATFORM ?= $(LOCAL_PLATFORM)
# Multi-arch set used for push targets (manifest list)
MULTI_PLATFORMS ?= linux/amd64,linux/arm64

# Load pinned versions if present
-include versions.env

.PHONY: help
help:
	@echo "Targets:"
	@echo "  build        Build image for local platform ($(LOCAL_PLATFORM)) and load into docker"
	@echo "               Override with PLATFORM=linux/amd64 or linux/arm64 for a specific arch"
	@echo "               Note: --load does not support multiple platforms; use 'make push' for multi-arch"
	@echo "  push         Build & push multi-arch image (and :latest)"
	@echo "  build-contract  Build warmed contract image (loaded locally)"
	@echo "  push-contract   Build & push warmed contract image (and :latest)"
	@echo "  build-shellcheck Build ShellCheck image (loaded locally)"
	@echo "  push-shellcheck  Build & push ShellCheck image (and :latest)"
	@echo "  version      Run image and print tool versions"
	@echo "  sbom-spdx    Generate SPDX SBOM for IMAGE (env IMAGE)"
	@echo "  sbom-os      Generate OS-only Syft SBOM for IMAGE (env IMAGE)"
	@echo "  lint-sh      Lint shell scripts with shellcheck (requires shellcheck)"
	@echo "  sbom-bundle  Generate SPDX + OS-only (and grype JSON) into sbom-bundle.tgz"

.PHONY: build
build:
	@if echo "$(PLATFORM)" | grep -q ','; then \
	  echo "Error: docker exporter does not support --load for multiple platforms: $(PLATFORM)" >&2; \
	  echo "Hint: use 'make push' for multi-arch or set PLATFORM=linux/amd64 (or linux/arm64) for local --load builds." >&2; \
	  exit 1; \
	fi
	docker buildx build --platform $(PLATFORM) -t $(BASE_IMAGE_NAME):$(TAG) -f base/Dockerfile base --load \
		$(if $(BASE_IMAGE),--build-arg BASE_IMAGE=$(BASE_IMAGE)) \
		$(if $(GO_VERSION),--build-arg GO_VERSION=$(GO_VERSION)) \
		$(if $(SYFT_VERSION),--build-arg SYFT_VERSION=$(SYFT_VERSION)) \
		$(if $(COSIGN_VERSION),--build-arg COSIGN_VERSION=$(COSIGN_VERSION)) \
		$(if $(TRIVY_VERSION),--build-arg TRIVY_VERSION=$(TRIVY_VERSION)) \
		$(if $(GITLEAKS_VERSION),--build-arg GITLEAKS_VERSION=$(GITLEAKS_VERSION)) \
		$(if $(GOSEC_VERSION),--build-arg GOSEC_VERSION=$(GOSEC_VERSION)) \
		$(if $(GOVULNCHECK_VERSION),--build-arg GOVULNCHECK_VERSION=$(GOVULNCHECK_VERSION))


.PHONY: push
push:
	docker buildx build --platform $(MULTI_PLATFORMS) -t $(BASE_IMAGE_NAME):$(TAG) -f base/Dockerfile base --push \
		$(if $(BASE_IMAGE),--build-arg BASE_IMAGE=$(BASE_IMAGE)) \
		$(if $(GO_VERSION),--build-arg GO_VERSION=$(GO_VERSION)) \
		$(if $(SYFT_VERSION),--build-arg SYFT_VERSION=$(SYFT_VERSION)) \
		$(if $(COSIGN_VERSION),--build-arg COSIGN_VERSION=$(COSIGN_VERSION)) \
		$(if $(TRIVY_VERSION),--build-arg TRIVY_VERSION=$(TRIVY_VERSION)) \
		$(if $(GITLEAKS_VERSION),--build-arg GITLEAKS_VERSION=$(GITLEAKS_VERSION)) \
		$(if $(GOSEC_VERSION),--build-arg GOSEC_VERSION=$(GOSEC_VERSION)) \
		$(if $(GOVULNCHECK_VERSION),--build-arg GOVULNCHECK_VERSION=$(GOVULNCHECK_VERSION))
	# also update moving tag latest
	docker buildx build --platform $(MULTI_PLATFORMS) -t $(BASE_IMAGE_NAME):latest -f base/Dockerfile base --push


.PHONY: build-contract
build-contract:
	@if [ "$(TAG)" = "dev-local" ]; then \
		DOCKER_BUILDKIT=1 docker build -t $(CONTRACT_IMAGE_NAME):$(TAG) -f contract/Dockerfile ../costscope \
			--build-arg BASE_IMAGE=$(BASE_IMAGE_NAME):$(TAG); \
	else \
		if echo "$(PLATFORM)" | grep -q ','; then \
		  echo "Error: --load does not support multiple platforms for build-contract: $(PLATFORM)" >&2; \
		  echo "Hint: use 'make push-contract' for multi-arch or set PLATFORM=linux/amd64 (or linux/arm64)." >&2; \
		  exit 1; \
		fi; \
			# For local builds, use classic docker build \
			DOCKER_BUILDKIT=1 docker build -t $(CONTRACT_IMAGE_NAME):$(TAG) -f contract/Dockerfile ../costscope \
				--build-arg BASE_IMAGE=$(BASE_IMAGE_NAME):$(TAG); \
	fi

.PHONY: push-contract
push-contract:
	# Build from project repository root to include go.mod files; set context to ../costscope
	docker buildx build --platform $(MULTI_PLATFORMS) -t $(CONTRACT_IMAGE_NAME):$(TAG) -f contract/Dockerfile ../costscope --push \
		--build-arg BASE_IMAGE=$(BASE_IMAGE_NAME):$(TAG)
	# also update moving tag latest
	docker buildx build --platform $(MULTI_PLATFORMS) -t $(CONTRACT_IMAGE_NAME):latest -f contract/Dockerfile ../costscope --push \
		--build-arg BASE_IMAGE=$(BASE_IMAGE_NAME):$(TAG)


.PHONY: build-shellcheck
build-shellcheck:
	@if echo "$(PLATFORM)" | grep -q ','; then \
	  echo "Error: --load does not support multiple platforms for build-shellcheck: $(PLATFORM)" >&2; \
	  echo "Hint: use 'make push-shellcheck' for multi-arch or set PLATFORM=linux/amd64 (or linux/arm64)." >&2; \
	  exit 1; \
	fi
	# Build ShellCheck image from local Dockerfile and load it to the local docker daemon
	docker buildx build --platform $(PLATFORM) -t $(SHELLCHECK_IMAGE_NAME):$(TAG) -f shellcheck/Dockerfile shellcheck --load \
		$(if $(BASE_IMAGE),--build-arg BASE_IMAGE=$(BASE_IMAGE))


.PHONY: push-shellcheck
push-shellcheck:
	# Build & push multi-arch ShellCheck image
	docker buildx build --platform $(MULTI_PLATFORMS) -t $(SHELLCHECK_IMAGE_NAME):$(TAG) -f shellcheck/Dockerfile shellcheck --push \
		$(if $(BASE_IMAGE),--build-arg BASE_IMAGE=$(BASE_IMAGE))
	# also update moving tag latest
	docker buildx build --platform $(MULTI_PLATFORMS) -t $(SHELLCHECK_IMAGE_NAME):latest -f shellcheck/Dockerfile shellcheck --push \
		$(if $(BASE_IMAGE),--build-arg BASE_IMAGE=$(BASE_IMAGE))


.PHONY: version
version:
	docker run --rm $(BASE_IMAGE_NAME):$(TAG)

.PHONY: sbom-spdx
sbom-spdx:
	@IMAGE=$${IMAGE:-$(BASE_IMAGE_NAME):latest}; \
	command -v syft >/dev/null || { echo "syft is required on host" >&2; exit 1; }; \
	bash scripts/syft-generate-spdx.sh "$$IMAGE" sbom.spdx.json; \
	echo "wrote sbom.spdx.json"

.PHONY: sbom-os
sbom-os:
	@IMAGE=$${IMAGE:-$(BASE_IMAGE_NAME):latest}; \
	command -v syft >/dev/null || { echo "syft is required on host" >&2; exit 1; }; \
	bash scripts/syft-generate-os-only.sh "$$IMAGE" sbom-os.syft.json; \
	echo "wrote sbom-os.syft.json"

.PHONY: lint-sh
lint-sh:
	@command -v shellcheck >/dev/null || { echo "shellcheck is required" >&2; exit 1; }
	shellcheck -x scripts/*.sh base/scripts/*.sh

.PHONY: sbom-bundle
sbom-bundle: sbom-spdx sbom-os
	@if command -v grype >/dev/null; then \
	  GRYPE_JSON_OUT=grype-report.json bash scripts/grype-scan-sbom.sh sbom.spdx.json || true; \
	  echo "grype-report.json generated (non-blocking)"; \
	else \
	  echo "grype not found on host; skipping grype JSON"; \
	fi
	@files="sbom.spdx.json sbom-os.syft.json"; [ -f grype-report.json ] && files="$$files grype-report.json"; \
	tar -czf sbom-bundle.tgz $$files; \
	echo "Bundle written to sbom-bundle.tgz"
