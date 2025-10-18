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
YQ_VERSION=""
GITCLIFF_VERSION=""

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
    --yq) YQ_VERSION="$2"; shift 2 ;;
    --gitcliff) GITCLIFF_VERSION="$2"; shift 2 ;;
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

install_yq() {
  local ver=$1
  # yq provides plain binaries named yq_linux_amd64 or yq_linux_arm64
  local asset_arch
  case "$ARCH" in
    amd64) asset_arch=amd64 ;;
    arm64) asset_arch=arm64 ;;
    *) echo "Unsupported ARCH for yq: $ARCH" >&2; exit 1 ;;
  esac
  curl -fsSL "https://github.com/mikefarah/yq/releases/download/${ver}/yq_linux_${asset_arch}" -o /usr/local/bin/yq
  chmod +x /usr/local/bin/yq
}

install_gitcliff() {
  local ver=$1
  # git-cliff assets vary by release; try a few common patterns in order.
  # Examples:
  #  - git-cliff-<ver>-x86_64-unknown-linux-gnu.tar.gz
  #  - git-cliff-<ver>-aarch64-unknown-linux-gnu.tar.gz
  #  - git-cliff-<ver>-linux-x86_64.tar.gz (older pattern)
  local arch_pattern
  case "$ARCH" in
    amd64) arch_pattern=("x86_64-unknown-linux-gnu" "linux-x86_64" "x86_64-unknown-linux-musl") ;;
    arm64) arch_pattern=("aarch64-unknown-linux-gnu" "linux-arm64" "aarch64-unknown-linux-musl") ;;
    *) echo "Unsupported ARCH for git-cliff: $ARCH" >&2; exit 1 ;;
  esac

  local found="" url="" tmpd="/tmp/gitcliff.$$" used_ext=""
  mkdir -p "$tmpd"
  # Some releases publish .tar.xz instead of .tar.gz. Try both.
  local exts=("tar.gz" "tar.xz")
  for pat in "${arch_pattern[@]}"; do
    for ext in "${exts[@]}"; do
      url="https://github.com/orhun/git-cliff/releases/download/${ver}/git-cliff-${ver#v}-${pat}.${ext}"
      # Always download to the same temp filename; we record ext used for extraction
      if curl -fsSL -o "$tmpd/git-cliff.tar" "$url"; then
        found="$url"
        used_ext="$ext"
        break 2
      fi
    done
  done
  if [[ -z "$found" ]]; then
    echo "Failed to download git-cliff ${ver} for ARCH=${ARCH}; tried patterns: ${arch_pattern[*]}" >&2
    rm -rf "$tmpd"
    exit 1
  fi
  # Extract depending on the archive compression
  case "$used_ext" in
    tar.gz) tar -C "$tmpd" -xzf "$tmpd/git-cliff.tar" ;;
    tar.xz) tar -C "$tmpd" -xJf "$tmpd/git-cliff.tar" ;;
    *) echo "Unknown archive type for git-cliff: $used_ext from $found" >&2; rm -rf "$tmpd"; exit 1 ;;
  esac
  # Find the binary in extracted content (path may include a directory)
  local bin
  bin=$(find "$tmpd" -type f -name git-cliff -perm -u+x | head -n1 || true)
  if [[ -z "$bin" ]]; then
    # Some archives may include just the binary named git-cliff in root
    if [[ -f "$tmpd/git-cliff" ]]; then
      bin="$tmpd/git-cliff"
    else
      echo "git-cliff binary not found in archive from $found" >&2
      rm -rf "$tmpd"
      exit 1
    fi
  fi
  install -m 0755 "$bin" /usr/local/bin/git-cliff
  rm -rf "$tmpd"
}

[[ -n "$SYFT_VERSION" ]] && install_syft "$SYFT_VERSION"
[[ -n "$COSIGN_VERSION" ]] && install_cosign "$COSIGN_VERSION"
[[ -n "$TRIVY_VERSION" ]] && install_trivy "$TRIVY_VERSION"
[[ -n "$GITLEAKS_VERSION" ]] && install_gitleaks "$GITLEAKS_VERSION"
[[ -n "$GOSEC_VERSION" ]] && install_gosec "$GOSEC_VERSION"
[[ -n "$GOVULNCHECK_VERSION" ]] && install_govulncheck "$GOVULNCHECK_VERSION"
[[ -n "$YQ_VERSION" ]] && install_yq "$YQ_VERSION"
[[ -n "$GITCLIFF_VERSION" ]] && install_gitcliff "$GITCLIFF_VERSION"

echo "Installed tools:" >&2
if command -v syft >/dev/null 2>&1; then syft version || true; fi
if command -v cosign >/dev/null 2>&1; then cosign version || true; fi
if command -v trivy >/dev/null 2>&1; then trivy --version || true; fi
if command -v gitleaks >/dev/null 2>&1; then gitleaks version || true; fi
if command -v gosec >/dev/null 2>&1; then gosec --version || true; fi
if command -v govulncheck >/dev/null 2>&1; then govulncheck -version || true; fi
if command -v yq >/dev/null 2>&1; then yq --version || true; fi
if command -v git-cliff >/dev/null 2>&1; then git-cliff --version || true; fi
