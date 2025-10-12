#!/usr/bin/env bash
set -euo pipefail

# syft-generate-spdx.sh: generate SPDX JSON SBOM for an image tag
# Usage: syft-generate-spdx.sh <image_ref> <output_path>

IMAGE_REF=${1:?image ref required}
OUT=${2:?output path required}

syft "$IMAGE_REF" -o spdx-json > "$OUT"
