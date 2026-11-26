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

All images support `linux/amd64` and `linux/arm64` unless noted otherwise. Click an image name for usage and configuration docs.

<!-- BEGIN:CONTAINER_CATALOG -->
### Infrastructure & Identity

| Image | Version | User | Shell | Description |
| :--- | :--- | :--- | :---: | :--- |
| [`keycloak`](nix/containers/keycloak/README.md) | `26.8.2` | `65532` | `bash` | Identity and access management for modern applications and services ([recipe](nix/containers/keycloak/default.nix)) |
| [`opentofu-runner`](nix/containers/opentofu-runner/README.md) | `0.17.0` | `65532` | `bash` | Flux Tofu Controller runner with OpenTofu ([recipe](nix/containers/opentofu-runner/default.nix)) |

### Monitoring & Hardware

| Image | Version | User | Shell | Description |
| :--- | :--- | :--- | :---: | :--- |
| [`nut`](nix/containers/nut/README.md) | `2.8.5` | `root` | `bash` | Network UPS Tools ([recipe](nix/containers/nut/default.nix)) |
| [`prometheus-nut-exporter`](nix/containers/prometheus-nut-exporter/README.md) | `3.2.5` | `65532` | — | Prometheus exporter for Network UPS Tools ([recipe](nix/containers/prometheus-nut-exporter/default.nix)) |

### Media & Downloads

| Image | Version | User | Shell | Description |
| :--- | :--- | :--- | :---: | :--- |
| [`ffmpeg`](nix/containers/ffmpeg/README.md) | `9.0.2` | `65532` | — | Minimal headless FFmpeg container ([recipe](nix/containers/ffmpeg/default.nix)) |
| ↳ [`ffmpeg-argo`](nix/containers/ffmpeg/README.md) | `9.0.2` | `65532` | `bash` | Minimal FFmpeg container with Argo Workflows progress reporting ([recipe](nix/containers/ffmpeg/argo/default.nix)) |
| [`prowlarr`](nix/containers/prowlarr/README.md) | `3.0.2.5780` | `65532` | — | Indexer manager/proxy built on the popular arr .net/reactjs base stack ([recipe](nix/containers/prowlarr/default.nix)) |
| [`qbittorrent`](nix/containers/qbittorrent/README.md) | `5.3.0` | `65532` | — | Featureful free software BitTorrent client ([recipe](nix/containers/qbittorrent/default.nix)) |
| [`radarr`](nix/containers/radarr/README.md) | `7.0.3.10918` | `65532` | — | Usenet/BitTorrent movie downloader ([recipe](nix/containers/radarr/default.nix)) |
| [`sabnzbd`](nix/containers/sabnzbd/README.md) | `5.1.3` | `65532` | — | Usenet NZB downloader, par2 repairer and auto extracting server ([recipe](nix/containers/sabnzbd/default.nix)) |
| [`sonarr`](nix/containers/sonarr/README.md) | `5.0.0.2997` | `65532` | — | Smart PVR for newsgroup and bittorrent users ([recipe](nix/containers/sonarr/default.nix)) |
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
