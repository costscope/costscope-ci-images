#!/usr/bin/env bash
set -euo pipefail

# install-syft-grype.sh: installs syft and grype pinned versions, arch-aware, with retries
# Usage: install-syft-grype.sh <syft_version> <grype_version>

SYFT_VER="${1:-v1.18.0}"
GRYPE_VER="${2:-v0.69.1}"

arch=$(uname -m)
case "$arch" in
  x86_64) ARCH=amd64 ;;
  aarch64|arm64) ARCH=arm64 ;;
  *) echo "Unsupported arch: $arch" >&2; exit 1 ;;
 esac

CURL="curl -fL --retry 5 --retry-delay 2 --retry-max-time 120 --retry-all-errors"

$CURL "https://github.com/anchore/syft/releases/download/${SYFT_VER}/syft_${SYFT_VER#v}_linux_${ARCH}.tar.gz" -o /tmp/syft.tgz
 tar -C /usr/local/bin -xzf /tmp/syft.tgz syft && rm -f /tmp/syft.tgz

$CURL "https://github.com/anchore/grype/releases/download/v${GRYPE_VER#v}/grype_${GRYPE_VER#v}_linux_${ARCH}.tar.gz" -o /tmp/grype.tgz
 tar -C /usr/local/bin -xzf /tmp/grype.tgz grype && rm -f /tmp/grype.tgz

syft version && grype version
