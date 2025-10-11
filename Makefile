IMAGE_NS ?= ghcr.io/costscope/ci
BASE_IMAGE_NAME ?= $(IMAGE_NS)/base
DATE_TAG := $(shell date -u +%Y%m%d)
GIT_SHA := $(shell git rev-parse --short=12 HEAD 2>/dev/null || echo dev)
TAG ?= $(DATE_TAG)-$(GIT_SHA)
PLATFORM ?= linux/amd64,linux/arm64

.PHONY: help
help:
	@echo "Targets: build, push, test, version"

.PHONY: build
build:
	docker buildx build --platform $(PLATFORM) -t $(BASE_IMAGE_NAME):$(TAG) -f base/Dockerfile base --load

.PHONY: push
push:
	docker buildx build --platform $(PLATFORM) -t $(BASE_IMAGE_NAME):$(TAG) -f base/Dockerfile base --push
	# also update moving tag latest
	docker buildx build --platform $(PLATFORM) -t $(BASE_IMAGE_NAME):latest -f base/Dockerfile base --push

.PHONY: version
version:
	docker run --rm $(BASE_IMAGE_NAME):$(TAG)
