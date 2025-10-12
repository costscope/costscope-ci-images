# CostScope CI Images

Prebuilt container images with pinned versions of the security and QA toolchain used in the CostScope repo. Mirrors versions in `.github/workflows/security.yml` for reproducible CI.

## Contents (base)

- OS: ubuntu:22.04
- Go: 1.24.x
- Tools:
  - Syft v1.18.0
  - Cosign v2.2.4
  - Trivy 0.56.2
  - Gitleaks 8.18.4
  - Gosec 2.21.4
  - govulncheck 1.1.3
  - git, make, jq

## Build

- Build locally (single-arch):

```sh
make build TAG=dev
```

- Push multi-arch to GHCR (requires login):

```sh
echo "$GITHUB_TOKEN" | docker login ghcr.io -u USERNAME --password-stdin
make push TAG=$(date -u +%Y%m%d)-$(git rev-parse --short=12 HEAD)
```

### Version Pins

Version pins live in `versions.env` (BASE_IMAGE, GO_VERSION, tool versions). The Makefile and CI load this file and pass values as Docker build args. You can override them in `versions.env` or via env/inputs in CI.

## Use in GitHub Actions (example)

Run gitleaks via docker instead of installing on runner:

```yaml
- name: Secrets scan (gitleaks)
  run: |
    docker run --rm -v ${{ github.workspace }}:/work -w /work \
  ghcr.io/costscope/ci-base:latest \
      bash -lc 'gitleaks detect -v -f json -r gitleaks-report.json || true'
```

Note: For Trivy image scan you still need host Docker (`docker build` / `docker load`). You can run Trivy from this image by passing through the Docker socket if desired:

```yaml
- name: Trivy image (via tool image)
  run: |
    docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  ghcr.io/costscope/ci-base:latest \
      bash -lc 'trivy image --format json -o trivy-image.json costscope:ci'
```

## Version Pins (CI Alignment)

Keep pins aligned with `security.yml` env. Update both places together. Consider adding a weekly rebuild workflow in this repo to refresh images.

## Notes / Troubleshooting

- Syft config files: when passing `-c <file>` Syft (via Viper) determines the format by filename extension. Temporary files without `.yaml` / `.yml` / `.json` will cause an error like: `invalid application config: unable to load config: Unsupported Config Type`. Our helper `scripts/syft-generate-os-only.sh` writes the temporary config with `.yaml` to avoid this.
- OS-only SBOM: `scripts/syft-generate-os-only.sh` intentionally includes only OS package managers (apk/dpkg/rpm). Distroless/minimal images may produce an empty SBOM.
- Grype report: CI stores JSON report as an artifact (`grype-ci-base.json`). Locally you can set `GRYPE_JSON_OUT=out.json` when calling `scripts/grype-scan-sbom.sh`.

## Local helpers

- `make sbom-spdx` — generate SPDX SBOM (env IMAGE defaults to `$(IMAGE_NS)/base:latest`).
- `make sbom-os` — generate OS-only Syft SBOM.
- `make sbom-bundle` — produce both SBOMs and, if grype is installed, `grype-report.json`, packed into `sbom-bundle.tgz`.
- `make lint-sh` — run shellcheck over project scripts.
