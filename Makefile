IMAGE_NS ?= ghcr.io/costscope/ci
BASE_IMAGE_NAME ?= $(IMAGE_NS)/base
DATE_TAG := $(shell date -u +%Y%m%d)
GIT_SHA := $(shell git rev-parse --short=12 HEAD 2>/dev/null || echo dev)
TAG ?= $(DATE_TAG)-$(GIT_SHA)
PLATFORM ?= linux/amd64,linux/arm64

# Load pinned versions if present
-include versions.env

.PHONY: help
help:
	@echo "Targets:"
	@echo "  build        Build multi-arch image (loaded locally)"
	@echo "  push         Build & push image (and :latest)"
	@echo "  version      Run image and print tool versions"
	@echo "  sbom-spdx    Generate SPDX SBOM for IMAGE (env IMAGE)"
	@echo "  sbom-os      Generate OS-only Syft SBOM for IMAGE (env IMAGE)"
	@echo "  lint-sh      Lint shell scripts with shellcheck (requires shellcheck)"
	@echo "  sbom-bundle  Generate SPDX + OS-only (and grype JSON) into sbom-bundle.tgz"

.PHONY: build
build:
	docker buildx build --platform $(PLATFORM) -t $(BASE_IMAGE_NAME):$(TAG) -f base/Dockerfile base --load \
		--build-arg BASE_IMAGE=$(BASE_IMAGE) \
		--build-arg GO_VERSION=$(GO_VERSION) \
		--build-arg SYFT_VERSION=$(SYFT_VERSION) \
		--build-arg COSIGN_VERSION=$(COSIGN_VERSION) \
		--build-arg TRIVY_VERSION=$(TRIVY_VERSION) \
		--build-arg GITLEAKS_VERSION=$(GITLEAKS_VERSION) \
		--build-arg GOSEC_VERSION=$(GOSEC_VERSION) \
		--build-arg GOVULNCHECK_VERSION=$(GOVULNCHECK_VERSION)

.PHONY: push
push:
	docker buildx build --platform $(PLATFORM) -t $(BASE_IMAGE_NAME):$(TAG) -f base/Dockerfile base --push \
		--build-arg BASE_IMAGE=$(BASE_IMAGE) \
		--build-arg GO_VERSION=$(GO_VERSION) \
		--build-arg SYFT_VERSION=$(SYFT_VERSION) \
		--build-arg COSIGN_VERSION=$(COSIGN_VERSION) \
		--build-arg TRIVY_VERSION=$(TRIVY_VERSION) \
		--build-arg GITLEAKS_VERSION=$(GITLEAKS_VERSION) \
		--build-arg GOSEC_VERSION=$(GOSEC_VERSION) \
		--build-arg GOVULNCHECK_VERSION=$(GOVULNCHECK_VERSION)
	# also update moving tag latest
	docker buildx build --platform $(PLATFORM) -t $(BASE_IMAGE_NAME):latest -f base/Dockerfile base --push

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
