#!/usr/bin/env bash
set -euo pipefail

# syft-generate-os-only.sh: generate OS-only Syft JSON SBOM
# Usage: syft-generate-os-only.sh <image_ref> <output_path>

IMAGE_REF=${1:?image ref required}
OUT=${2:?output path required}

# Create a temp config enabling only OS catalogers
CFG=$(mktemp)
cat > "$CFG" <<'YAML'
application:
  defaultOutput: "syft-json"
package:
  catalogers:
    enabled:
      - "apkdb-cataloger"
      - "dpkgdb-cataloger"
      - "rpmdb-cataloger"
YAML

syft "$IMAGE_REF" -c "$CFG" -o syft-json > "$OUT"
rm -f "$CFG"
