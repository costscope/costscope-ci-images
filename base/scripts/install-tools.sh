#!/usr/bin/env bash
set -euo pipefail

# Simple installer for pinned security tools
# Supports amd64 and arm64

SYFT_VERSION=""
COSIGN_VERSION=""
TRIVY_VERSION=""
GITLEAKS_VERSION=""
GOSEC_VERSION=""
GOVULNCHECK_VERSION=""

arch=$(uname -m)
case "$arch" in
  x86_64) ARCH=amd64 ;;
  aarch64|arm64) ARCH=arm64 ;;
  *) echo "Unsupported arch: $arch" >&2; exit 1 ;;
esac

# Map arch names for tools with non-standard asset naming
# - Trivy uses Linux-64bit / Linux-ARM64
# - Gitleaks uses linux_x64 / linux_arm64
case "$ARCH" in
  amd64)
    TRIVY_ASSET_ARCH="64bit"
    GITLEAKS_ASSET_ARCH="x64"
    ;;
  arm64)
    TRIVY_ASSET_ARCH="ARM64"
    GITLEAKS_ASSET_ARCH="arm64"
    ;;
  *)
    echo "Unsupported mapped ARCH: $ARCH" >&2; exit 1
    ;;
esac

while [[ $# -gt 0 ]]; do
  case "$1" in
    --syft) SYFT_VERSION="$2"; shift 2 ;;
    --cosign) COSIGN_VERSION="$2"; shift 2 ;;
    --trivy) TRIVY_VERSION="$2"; shift 2 ;;
    --gitleaks) GITLEAKS_VERSION="$2"; shift 2 ;;
    --gosec) GOSEC_VERSION="$2"; shift 2 ;;
    --govulncheck) GOVULNCHECK_VERSION="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

install_syft() {
  local ver=$1
  curl -fsSL "https://github.com/anchore/syft/releases/download/${ver}/syft_${ver#v}_linux_${ARCH}.tar.gz" -o /tmp/syft.tgz
  tar -C /usr/local/bin -xzf /tmp/syft.tgz syft
  rm /tmp/syft.tgz
}

install_cosign() {
  local ver=$1
  curl -fsSL "https://github.com/sigstore/cosign/releases/download/${ver}/cosign-linux-${ARCH}" -o /usr/local/bin/cosign
  chmod +x /usr/local/bin/cosign
}

install_trivy() {
  local ver=$1
  # Trivy release assets are named like: trivy_<ver>_Linux-64bit.tar.gz or Linux-ARM64
  curl -fsSL "https://github.com/aquasecurity/trivy/releases/download/v${ver}/trivy_${ver}_Linux-${TRIVY_ASSET_ARCH}.tar.gz" -o /tmp/trivy.tgz
  tar -C /usr/local/bin -xzf /tmp/trivy.tgz trivy
  rm /tmp/trivy.tgz
}

install_gitleaks() {
  local ver=$1
  # Gitleaks uses linux_x64 or linux_arm64 asset naming
  curl -fsSL "https://github.com/gitleaks/gitleaks/releases/download/v${ver}/gitleaks_${ver}_linux_${GITLEAKS_ASSET_ARCH}.tar.gz" -o /tmp/gitleaks.tgz
  tar -C /usr/local/bin -xzf /tmp/gitleaks.tgz gitleaks
  rm /tmp/gitleaks.tgz
}

install_gosec() {
  local ver=$1
  GOBIN=/usr/local/bin go install "github.com/securego/gosec/v2/cmd/gosec@v${ver}"
}

install_govulncheck() {
  local ver=$1
  GOBIN=/usr/local/bin go install "golang.org/x/vuln/cmd/govulncheck@v${ver}"
}

[[ -n "$SYFT_VERSION" ]] && install_syft "$SYFT_VERSION"
[[ -n "$COSIGN_VERSION" ]] && install_cosign "$COSIGN_VERSION"
[[ -n "$TRIVY_VERSION" ]] && install_trivy "$TRIVY_VERSION"
[[ -n "$GITLEAKS_VERSION" ]] && install_gitleaks "$GITLEAKS_VERSION"
[[ -n "$GOSEC_VERSION" ]] && install_gosec "$GOSEC_VERSION"
[[ -n "$GOVULNCHECK_VERSION" ]] && install_govulncheck "$GOVULNCHECK_VERSION"

echo "Installed tools:" >&2
command -v syft >/dev/null && syft version || true
command -v cosign >/dev/null && cosign version || true
command -v trivy >/dev/null && trivy --version || true
command -v gitleaks >/dev/null && gitleaks version || true
command -v gosec >/dev/null && gosec --version || true
command -v govulncheck >/dev/null && govulncheck -version || true
