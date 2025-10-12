#!/usr/bin/env bash
set -euo pipefail

# grype-scan-sbom.sh: scan an SBOM with grype
# Usage: grype-scan-sbom.sh <sbom_path>

SBOM=${1:?sbom path required}

# Optional JSON output path via env GRYPE_JSON_OUT (e.g., grype-report.json)
JSON_OUT=${GRYPE_JSON_OUT:-}

# Respect env overrides if provided
FAIL_ON_LEVEL=${GRYPE_FAIL_ON:-critical}
ONLY_FIXED_FLAG=""
if [ "${GRYPE_ONLY_FIXED:-true}" = "true" ]; then
	ONLY_FIXED_FLAG="--only-fixed"
fi

echo "[grype] scanning SBOM: ${SBOM} (fail-on=${FAIL_ON_LEVEL} only-fixed=${GRYPE_ONLY_FIXED:-true} json-out=${JSON_OUT:-no})"
if [ -n "$JSON_OUT" ]; then
	# JSON output to file (quiet to avoid mixing with JSON)
	GRYPE_CHECK_FOR_APP_UPDATE=${GRYPE_CHECK_FOR_APP_UPDATE:-false} \
		grype "sbom:${SBOM}" --fail-on "${FAIL_ON_LEVEL}" ${ONLY_FIXED_FLAG} --add-cpes-if-none -o json -q > "$JSON_OUT"
	rc=$?
else
	GRYPE_CHECK_FOR_APP_UPDATE=${GRYPE_CHECK_FOR_APP_UPDATE:-false} \
		grype "sbom:${SBOM}" --fail-on "${FAIL_ON_LEVEL}" ${ONLY_FIXED_FLAG} --add-cpes-if-none
	rc=$?
fi

# Persist exit code for CI if requested
if [ -n "${GRYPE_EXIT_CODE_FILE:-}" ]; then
	echo "$rc" > "${GRYPE_EXIT_CODE_FILE}"
fi
exit "$rc"
