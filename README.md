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

All images support `linux/amd64` and `linux/arm64` unless noted otherwise (📦 GHCR image · ❄️ Nix recipe).

<!-- BEGIN:CONTAINER_CATALOG -->
### Infrastructure & Identity

| Container | Version | Non-Root | RO Root | Shell | Features | Description |
| :--- | :--- | :---: | :---: | :---: | :---: | :--- |
| [`keycloak`](nix/containers/keycloak/README.md) [📦](https://ghcr.io/kevinastone/nix-containers/keycloak "GHCR image") [❄️](nix/containers/keycloak/default.nix "Nix recipe") | `26.8.2` | ✓ | ✓ | ✓ | — | Identity and access management for modern applications and services |
| [`opentofu-runner`](nix/containers/opentofu-runner/README.md) [📦](https://ghcr.io/kevinastone/nix-containers/opentofu-runner "GHCR image") [❄️](nix/containers/opentofu-runner/default.nix "Nix recipe") | `0.17.0` | ✓ | ✓ | ✓ | — | Flux Tofu Controller runner with OpenTofu |

### Networking

| Container | Version | Non-Root | RO Root | Shell | Features | Description |
| :--- | :--- | :---: | :---: | :---: | :---: | :--- |
| [`unbound`](nix/containers/unbound/README.md) [📦](https://ghcr.io/kevinastone/nix-containers/unbound "GHCR image") [❄️](nix/containers/unbound/default.nix "Nix recipe") | `1.26.2` | ✓ | ✓ | — | — | Validating, recursive, and caching DNS resolver |

### Monitoring & Hardware

| Container | Version | Non-Root | RO Root | Shell | Features | Description |
| :--- | :--- | :---: | :---: | :---: | :---: | :--- |
| [`nut`](nix/containers/nut/README.md) [📦](https://ghcr.io/kevinastone/nix-containers/nut "GHCR image") [❄️](nix/containers/nut/default.nix "Nix recipe") | `2.8.5` | — | ✓ | ✓ | — | Network UPS Tools |
| [`prometheus-nut-exporter`](nix/containers/prometheus-nut-exporter/README.md) [📦](https://ghcr.io/kevinastone/nix-containers/prometheus-nut-exporter "GHCR image") [❄️](nix/containers/prometheus-nut-exporter/default.nix "Nix recipe") | `3.2.5` | ✓ | ✓ | — | — | Prometheus exporter for Network UPS Tools |

### Media & Downloads

| Container | Version | Non-Root | RO Root | Shell | Features | Description |
| :--- | :--- | :---: | :---: | :---: | :---: | :--- |
| [`bazarr`](nix/containers/bazarr/README.md) [📦](https://ghcr.io/kevinastone/nix-containers/bazarr "GHCR image") [❄️](nix/containers/bazarr/default.nix "Nix recipe") | `1.6.2` | ✓ | ✓ | — | — | Subtitle manager for Sonarr and Radarr |
| [`calibre-web`](nix/containers/calibre-web/README.md) [📦](https://ghcr.io/kevinastone/nix-containers/calibre-web "GHCR image") [❄️](nix/containers/calibre-web/default.nix "Nix recipe") | `0.6.27` | ✓ | ✓ | — | — | Web app for browsing, reading and downloading eBooks stored in a Calibre database |
| [`ffmpeg`](nix/containers/ffmpeg/README.md) [📦](https://ghcr.io/kevinastone/nix-containers/ffmpeg "GHCR image") [❄️](nix/containers/ffmpeg/default.nix "Nix recipe") | `9.0.2` | ✓ | ✓ | — | — | Minimal headless FFmpeg container |
| ↳ [`ffmpeg-argo`](nix/containers/ffmpeg/argo/README.md) [📦](https://ghcr.io/kevinastone/nix-containers/ffmpeg-argo "GHCR image") [❄️](nix/containers/ffmpeg/argo/default.nix "Nix recipe") | `9.0.2` | ✓ | ✓ | ✓ | — | Minimal FFmpeg container with Argo Workflows progress reporting |
| [`jackett`](nix/containers/jackett/README.md) [📦](https://ghcr.io/kevinastone/nix-containers/jackett "GHCR image") [❄️](nix/containers/jackett/default.nix "Nix recipe") | `0.24.3036` | ✓ | ✓ | — | — | API Support for your favorite torrent trackers |
| [`lidarr`](nix/containers/lidarr/README.md) [📦](https://ghcr.io/kevinastone/nix-containers/lidarr "GHCR image") [❄️](nix/containers/lidarr/default.nix "Nix recipe") | `3.1.6.5079` | ✓ | ✓ | — | — | Usenet/BitTorrent music downloader |
| [`prowlarr`](nix/containers/prowlarr/README.md) [📦](https://ghcr.io/kevinastone/nix-containers/prowlarr "GHCR image") [❄️](nix/containers/prowlarr/default.nix "Nix recipe") | `3.0.2.5780` | ✓ | ✓ | — | — | Indexer manager/proxy built on the popular arr .net/reactjs base stack |
| [`qbittorrent`](nix/containers/qbittorrent/README.md) [📦](https://ghcr.io/kevinastone/nix-containers/qbittorrent "GHCR image") [❄️](nix/containers/qbittorrent/default.nix "Nix recipe") | `5.3.0` | ✓ | ✓ | — | — | Featureful free software BitTorrent client |
| [`radarr`](nix/containers/radarr/README.md) [📦](https://ghcr.io/kevinastone/nix-containers/radarr "GHCR image") [❄️](nix/containers/radarr/default.nix "Nix recipe") | `7.0.3.10918` | ✓ | ✓ | — | — | Usenet/BitTorrent movie downloader |
| [`sabnzbd`](nix/containers/sabnzbd/README.md) [📦](https://ghcr.io/kevinastone/nix-containers/sabnzbd "GHCR image") [❄️](nix/containers/sabnzbd/default.nix "Nix recipe") | `5.1.3` | ✓ | ✓ | — | — | Usenet NZB downloader, par2 repairer and auto extracting server |
| [`sonarr`](nix/containers/sonarr/README.md) [📦](https://ghcr.io/kevinastone/nix-containers/sonarr "GHCR image") [❄️](nix/containers/sonarr/default.nix "Nix recipe") | `5.0.0.2997` | ✓ | ✓ | — | — | Smart PVR for newsgroup and bittorrent users |
| [`tautulli`](nix/containers/tautulli/README.md) [📦](https://ghcr.io/kevinastone/nix-containers/tautulli "GHCR image") [❄️](nix/containers/tautulli/default.nix "Nix recipe") | `2.19.1` | ✓ | ✓ | — | — | Python based monitoring and tracking tool for Plex Media Server |
| [`transmission`](nix/containers/transmission/README.md) [📦](https://ghcr.io/kevinastone/nix-containers/transmission "GHCR image") [❄️](nix/containers/transmission/default.nix "Nix recipe") | `4.1.4` | ✓ | ✓ | — | — | Fast, easy and free BitTorrent client |
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
