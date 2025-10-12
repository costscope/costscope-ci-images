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
# a recognizable file extension for the config; use a temp directory for
# portability (GNU/BSD mktemp differences) and write a .yaml file inside it.
TMPDIR="$(mktemp -d 2>/dev/null || mktemp -d -t syftcfg.XXXXXX)"
CFG="${TMPDIR}/syft-config.yaml"
trap 'rm -rf "$TMPDIR"' EXIT

cat > "$CFG" <<'YAML'
package:
  catalogers:
    enabled:
      - apkdb-cataloger
      - dpkgdb-cataloger
      - rpmdb-cataloger
YAML

syft "$IMAGE_REF" -c "$CFG" -o syft-json > "$OUT"
