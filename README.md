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

## Version Pins

Keep pins aligned with `security.yml` env. Update both places together. Consider adding a weekly rebuild workflow in this repo to refresh images.
