# nix-containers 📦

[![CI/CD Status](https://github.com/kevinastone/nix-containers/actions/workflows/ci.yaml/badge.svg)](https://github.com/kevinastone/nix-containers/actions/workflows/ci.yaml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Nix Built](https://img.shields.io/badge/Built%20With-Nix-blue.svg)](https://nixos.org)

Minimal, reproducible, multi-architecture (`linux/amd64` and `linux/arm64`) OCI container images built with Nix for Kubernetes, GitOps, and homelab workloads.

- **Minimal & Rootless by Default**: Distroless-style closures without package managers or base-image bloat, running as numeric non-root (`65532:65532`) and validated against the Kubernetes `restricted` Pod Security Standard.
- **Multi-Architecture**: Published as multi-arch OCI indexes supporting `linux/amd64` and `linux/arm64`.
- **Signed & Attested**: Keyless Sigstore `cosign` signatures, GitHub SLSA build provenance, and per-architecture SPDX SBOM attestations attached to every published image.

---

## 🚀 Pulling & Pinning Images

All images are published to GitHub Container Registry under:

```text
ghcr.io/kevinastone/nix-containers/<image>:<tag>
```

- **SemVer Tags**: Releases publish `<major>.<minor>.<patch>`, `<major>.<minor>`, and `<major>` tags (compatible out of the box with [Renovate](https://docs.renovatebot.com/) and [Flux `ImagePolicy`](https://fluxcd.io/flux/components/image/imagepolicies/)).
- **Rolling Tag**: `:main` tracks the latest verified build from the `main` branch.
- **Variants**: Role- or flavor-specific variants publish to distinct `<name>-<variant>` repositories (for example, `ffmpeg` and `ffmpeg-argo`) so standard SemVer automation works without tag-suffix regexes.

---

## 🐳 Containers

All images support `linux/amd64` and `linux/arm64` unless noted otherwise.

<!-- BEGIN:CONTAINER_CATALOG -->
### Infrastructure & Identity

| Container | Version | Description |
| :--- | :--- | :--- |
| `keycloak` ([readme](nix/containers/keycloak/README.md), [image](https://ghcr.io/kevinastone/nix-containers/keycloak), [recipe](nix/containers/keycloak/default.nix)) | `26.8.2` | Identity and access management for modern applications and services |
| `opentofu-runner` ([readme](nix/containers/opentofu-runner/README.md), [image](https://ghcr.io/kevinastone/nix-containers/opentofu-runner), [recipe](nix/containers/opentofu-runner/default.nix)) | `0.17.0` | Flux Tofu Controller runner with OpenTofu |

### Monitoring & Hardware

| Container | Version | Description |
| :--- | :--- | :--- |
| `nut` ([readme](nix/containers/nut/README.md), [image](https://ghcr.io/kevinastone/nix-containers/nut), [recipe](nix/containers/nut/default.nix)) | `2.8.5` | Network UPS Tools |
| `prometheus-nut-exporter` ([readme](nix/containers/prometheus-nut-exporter/README.md), [image](https://ghcr.io/kevinastone/nix-containers/prometheus-nut-exporter), [recipe](nix/containers/prometheus-nut-exporter/default.nix)) | `3.2.5` | Prometheus exporter for Network UPS Tools |

### Media & Downloads

| Container | Version | Description |
| :--- | :--- | :--- |
| `bazarr` ([readme](nix/containers/bazarr/README.md), [image](https://ghcr.io/kevinastone/nix-containers/bazarr), [recipe](nix/containers/bazarr/default.nix)) | `1.6.2` | Subtitle manager for Sonarr and Radarr |
| `ffmpeg` ([readme](nix/containers/ffmpeg/README.md), [image](https://ghcr.io/kevinastone/nix-containers/ffmpeg), [recipe](nix/containers/ffmpeg/default.nix)) | `9.0.2` | Minimal headless FFmpeg container |
| ↳ `ffmpeg-argo` ([readme](nix/containers/ffmpeg/argo/README.md), [image](https://ghcr.io/kevinastone/nix-containers/ffmpeg-argo), [recipe](nix/containers/ffmpeg/argo/default.nix)) | `9.0.2` | Minimal FFmpeg container with Argo Workflows progress reporting |
| `prowlarr` ([readme](nix/containers/prowlarr/README.md), [image](https://ghcr.io/kevinastone/nix-containers/prowlarr), [recipe](nix/containers/prowlarr/default.nix)) | `3.0.2.5780` | Indexer manager/proxy built on the popular arr .net/reactjs base stack |
| `qbittorrent` ([readme](nix/containers/qbittorrent/README.md), [image](https://ghcr.io/kevinastone/nix-containers/qbittorrent), [recipe](nix/containers/qbittorrent/default.nix)) | `5.3.0` | Featureful free software BitTorrent client |
| `radarr` ([readme](nix/containers/radarr/README.md), [image](https://ghcr.io/kevinastone/nix-containers/radarr), [recipe](nix/containers/radarr/default.nix)) | `7.0.3.10918` | Usenet/BitTorrent movie downloader |
| `sabnzbd` ([readme](nix/containers/sabnzbd/README.md), [image](https://ghcr.io/kevinastone/nix-containers/sabnzbd), [recipe](nix/containers/sabnzbd/default.nix)) | `5.1.3` | Usenet NZB downloader, par2 repairer and auto extracting server |
| `sonarr` ([readme](nix/containers/sonarr/README.md), [image](https://ghcr.io/kevinastone/nix-containers/sonarr), [recipe](nix/containers/sonarr/default.nix)) | `5.0.0.2997` | Smart PVR for newsgroup and bittorrent users |
<!-- END:CONTAINER_CATALOG -->

---

## 🔐 Verifying Images

Published images can be verified using Sigstore `cosign` or the GitHub CLI:

```bash
# Verify keyless Sigstore signature
cosign verify \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  --certificate-identity-regexp '^https://github\.com/kevinastone/nix-containers/\.github/workflows/.+@refs/heads/main$' \
  ghcr.io/kevinastone/nix-containers/ffmpeg:main

# Verify GitHub SLSA build provenance attestation (on the multi-arch OCI index)
gh attestation verify oci://ghcr.io/kevinastone/nix-containers/ffmpeg:main \
  --owner kevinastone

# Verify per-architecture SPDX SBOM attestation
AMD64_DIGEST=$(regctl image digest --platform linux/amd64 ghcr.io/kevinastone/nix-containers/ffmpeg:main)
gh attestation verify "oci://ghcr.io/kevinastone/nix-containers/ffmpeg@${AMD64_DIGEST}" \
  --owner kevinastone \
  --predicate-type https://spdx.dev/Document/v2.3
```

---

## 📚 Documentation

- **[Contributing & Local Development](docs/contributing.md)** — Scaffolding new containers, local builds, testing, layer inspection, and variant guidelines.
- **[`containerTools` Reference](docs/container-tools.md)** — Declarative options for `containerTools.buildLayeredImage` (`user`, `dirs`, `enableShell`, `variants`, `structureTest`, and OCI runtime config).
- **[CI/CD & Architecture](docs/architecture.md)** — Nix layered streaming, derivation-hash CI skipping, atomic multi-arch publishing, and supply-chain attestations.
