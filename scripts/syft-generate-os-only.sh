#!/usr/bin/env bash
set -euo pipefail

# syft-generate-os-only.sh: generate OS-only Syft JSON SBOM
# Usage: syft-generate-os-only.sh <image_ref> <output_path>
# Notes:
# - Captures only OS package managers (apk, dpkg, rpm). No language pkg managers.
# - Distroless/minimal images may yield empty results.

IMAGE_REF=${1:?image ref required}
OUT=${2:?output path required}

# Create a temp config enabling only OS catalogers. Syft (via viper) requires
# a recognizable file extension for the config; ensure we write a .yaml file.
TMP=$(mktemp -t syftcfg)
CFG="${TMP}.yaml"
mv "$TMP" "$CFG"
trap 'rm -f "$CFG"' EXIT

cat > "$CFG" <<'YAML'
package:
  catalogers:
    enabled:
      - apkdb-cataloger
      - dpkgdb-cataloger
      - rpmdb-cataloger
YAML

syft "$IMAGE_REF" -c "$CFG" -o syft-json > "$OUT"
