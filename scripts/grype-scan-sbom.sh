#!/usr/bin/env bash
set -euo pipefail

# grype-scan-sbom.sh: scan an SBOM with grype
# Usage: grype-scan-sbom.sh <sbom_path>

SBOM=${1:?sbom path required}

# Respect env overrides if provided
FAIL_ON_LEVEL=${GRYPE_FAIL_ON:-critical}
ONLY_FIXED_FLAG=""
if [ "${GRYPE_ONLY_FIXED:-true}" = "true" ]; then
	ONLY_FIXED_FLAG="--only-fixed"
fi

echo "[grype] scanning SBOM: ${SBOM} (fail-on=${FAIL_ON_LEVEL} only-fixed=${GRYPE_ONLY_FIXED:-true})"
GRYPE_CHECK_FOR_APP_UPDATE=${GRYPE_CHECK_FOR_APP_UPDATE:-false} \
	grype "sbom:${SBOM}" --fail-on "${FAIL_ON_LEVEL}" ${ONLY_FIXED_FLAG} --add-cpes-if-none
