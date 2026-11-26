# nix-containers 📦

[![CI/CD Status](https://github.com/kevinastone/nix-containers/actions/workflows/ci.yaml/badge.svg)](https://github.com/kevinastone/nix-containers/actions/workflows/ci.yaml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Nix Built](https://img.shields.io/badge/Built%20With-Nix-blue.svg)](https://nixos.org)

Minimal, fully reproducible, multi-architecture (`linux/amd64` and `linux/arm64`) OCI container images built with Nix for homelab and cloud-native workloads.

Images are published to GitHub Container Registry under:

```text
ghcr.io/kevinastone/nix-containers/<container>
```

---

## 📖 Table of Contents

- [Overview](#overview)
- [Containers](#containers)
- [Adding a New Container](#adding-a-new-container)
- [Local Development](#local-development)
  - [Nix DevShell](#nix-devshell)
  - [Building & Testing an Image](#building--testing-an-image)
  - [Debugging Layer Efficiency & Closure Size](#debugging-layer-efficiency--closure-size)
  - [Code Formatting](#code-formatting)
- [CI/CD & Publishing](#cicd--publishing)

---

## 🔍 Overview

This repository uses Nix Flakes and `dockerTools` to build deterministic, minimal OCI container images without package managers or unnecessary base-image clutter.

- **Minimal & Secure**: Packages only the target software and its exact runtime dependencies.
- **Multi-Architecture Support**: Automatically built and published for both `linux/amd64` and `linux/arm64`.
- **Auto-Discovered CI**: Adding a new container recipe under `nix/containers/<name>/default.nix` automatically exposes it as a flake package (`.#<name>`) and adds it to the CI/CD build and publish matrix.
- **Reproducible Builds**: Pins all dependency versions via `flake.lock`.

---

## 🐳 Containers

<!-- BEGIN:CONTAINER_CATALOG -->
| Container | Image | Platforms | Description |
| --- | --- | --- | --- |
| [`ffmpeg`](nix/containers/ffmpeg/README.md) | [`ghcr.io/kevinastone/nix-containers/ffmpeg`](https://ghcr.io/kevinastone/nix-containers/ffmpeg) | `linux/amd64`, `linux/arm64` | Minimal ffmpeg container with Argo Workflows progress reporting ([recipe](nix/containers/ffmpeg/default.nix)) |
| [`keycloak`](nix/containers/keycloak/README.md) | [`ghcr.io/kevinastone/nix-containers/keycloak`](https://ghcr.io/kevinastone/nix-containers/keycloak) | `linux/amd64`, `linux/arm64` | Identity and access management for modern applications and services ([recipe](nix/containers/keycloak/default.nix)) |
| [`nut`](nix/containers/nut/README.md) | [`ghcr.io/kevinastone/nix-containers/nut`](https://ghcr.io/kevinastone/nix-containers/nut) | `linux/amd64`, `linux/arm64` | Network UPS Tools ([recipe](nix/containers/nut/default.nix)) |
| [`opentofu-runner`](nix/containers/opentofu-runner/README.md) | [`ghcr.io/kevinastone/nix-containers/opentofu-runner`](https://ghcr.io/kevinastone/nix-containers/opentofu-runner) | `linux/amd64`, `linux/arm64` | Flux Tofu Controller runner with OpenTofu ([recipe](nix/containers/opentofu-runner/default.nix)) |
| [`prowlarr`](nix/containers/prowlarr/README.md) | [`ghcr.io/kevinastone/nix-containers/prowlarr`](https://ghcr.io/kevinastone/nix-containers/prowlarr) | `linux/amd64`, `linux/arm64` | Indexer manager/proxy built on the popular arr .net/reactjs base stack ([recipe](nix/containers/prowlarr/default.nix)) |
| [`qbittorrent`](nix/containers/qbittorrent/README.md) | [`ghcr.io/kevinastone/nix-containers/qbittorrent`](https://ghcr.io/kevinastone/nix-containers/qbittorrent) | `linux/amd64`, `linux/arm64` | Featureful free software BitTorrent client ([recipe](nix/containers/qbittorrent/default.nix)) |
| [`radarr`](nix/containers/radarr/README.md) | [`ghcr.io/kevinastone/nix-containers/radarr`](https://ghcr.io/kevinastone/nix-containers/radarr) | `linux/amd64`, `linux/arm64` | Usenet/BitTorrent movie downloader ([recipe](nix/containers/radarr/default.nix)) |
| [`sabnzbd`](nix/containers/sabnzbd/README.md) | [`ghcr.io/kevinastone/nix-containers/sabnzbd`](https://ghcr.io/kevinastone/nix-containers/sabnzbd) | `linux/amd64`, `linux/arm64` | Usenet NZB downloader, par2 repairer and auto extracting server ([recipe](nix/containers/sabnzbd/default.nix)) |
| [`sonarr`](nix/containers/sonarr/README.md) | [`ghcr.io/kevinastone/nix-containers/sonarr`](https://ghcr.io/kevinastone/nix-containers/sonarr) | `linux/amd64`, `linux/arm64` | Smart PVR for newsgroup and bittorrent users ([recipe](nix/containers/sonarr/default.nix)) |
<!-- END:CONTAINER_CATALOG -->

---

## ➕ Adding a New Container

Inside `nix develop` (or `direnv`), scaffold a new container with `just`:

```bash
just new <name>
# or if the nixpkgs attribute differs from the image name:
just new <name> --package <nixpkgs-attr>
```

This creates `nix/containers/<name>/` (`default.nix`, `structure-test.yaml`, and `README.md`), tracks the files, updates the `README.md` catalog, and runs `nix fmt`:

1. Customize `nix/containers/<name>/default.nix` (`containerTools.buildLayeredImage`). Passing `package` automatically derives `name`, `tag`, `description`, `config.Entrypoint`, and package inclusion. Non-root user (`65532:65532` with `/home/nonroot` and `HOME=/home/nonroot`, customizable via `user = { uid = 1000; ... }`), `caCertificates`, `tzdata`, writable `/tmp`, declarative `dirs` ownership/permissions, and standard OCI labels like `org.opencontainers.image.source` are applied automatically (and `enableShell = true` adds `bash` + `coreutils`).
2. Update `nix/containers/<name>/structure-test.yaml` (`container-structure-test` config) to verify runtime behavior, commands, and metadata (every container also gets `passthru.tests.oci` and, when `runAsNonRoot = true`, `passthru.tests.restricted` automatically).
3. Run `just readme` (if `description` changed), `just fmt`, and `just check`.
4. Build and smoke-test locally with `just test <name>` (works on both Linux and macOS with a Linux builder + OrbStack/Docker/Podman).

`nix/modules/containers.nix` automatically discovers all subdirectories under `nix/containers/` containing a `default.nix`, exposes them as flake packages on their supported platforms, and computes `lib.ci` for GitHub Actions.

---

## 💻 Local Development

### Nix DevShell

Enter the development shell (or allow `.envrc` via `direnv`) to load `just`, `new-container`, `update-readme`, `dive`, `dive-archive`, `nix-tree`, `nvd`, `regctl`, `skopeo`, `cosign`, `container-structure-test`, and `nushell`:

```bash
nix develop
just --list
```

### Building & Testing an Image

Use `just` to target the matching Linux container derivation automatically (`.#packages.<arch>-linux.<name>`, working seamlessly on both Linux and macOS):

```bash
just build ffmpeg
just test ffmpeg
```

On Linux, you can also invoke Nix directly:

```bash
nix build .#ffmpeg
nix run .#ffmpeg.test -- ./result
```

### Debugging Layer Efficiency & Closure Size

Inspect container layers in `dive` or trace Nix dependency bloat (`why-depends`) in `nix-tree`:

```bash
just dive ffmpeg
just inspect ffmpeg
```

### Code Formatting

This repository uses `treefmt-nix` (`deadnix`, `statix`, `nixfmt`) to enforce unified formatting. Before making a pull request, run:

```bash
nix fmt
```

---

## 🤖 CI/CD & Publishing

The GitHub Actions workflows defined in [.github/workflows/ci.yaml](.github/workflows/ci.yaml), [.github/workflows/_build.yaml](.github/workflows/_build.yaml), and [.github/workflows/_publish.yaml](.github/workflows/_publish.yaml) automate validation and deployment:

1. **Linting & Change Detection**: Runs `nix flake check`, evaluates `.#lib.ci` (which computes each container's supported architectures and Nix `drvPath`s), and filters out containers whose published `:main` OCI index already matches `dev.nix-containers.drv.<arch>`.
2. **Independent Per-Container Pipelines**: Spawns an isolated `_build.yaml` check on PRs (read-only, fork-safe) or `_publish.yaml` pipeline on `main` per changed container so fast builds push immediately without waiting on slower containers.
3. **Upstream Tagging**: Tags each published image with its Nix `.imageTag` (plus semver and `:main`) directly from `.#lib.ci`.
4. **Multi-Arch Push, Signing & Provenance**: Combines architecture builds into a multi-arch OCI index using `push-multiarch`, publishes to `ghcr.io/<owner>/<repo>/<container>`, signs the index digest keyless with Sigstore `cosign`, and attaches GitHub SLSA build provenance attestations.

### Verifying Images

Published images can be verified using Sigstore `cosign` or the GitHub CLI:

```bash
# Verify keyless Sigstore signature
cosign verify \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  --certificate-identity-regexp '^https://github\.com/kevinastone/nix-containers/\.github/workflows/.+@refs/heads/main$' \
  ghcr.io/kevinastone/nix-containers/ffmpeg:main

# Verify GitHub SLSA build provenance attestation
gh attestation verify oci://ghcr.io/kevinastone/nix-containers/ffmpeg:main \
  --owner kevinastone

# Verify SPDX SBOM attestation
gh attestation verify oci://ghcr.io/kevinastone/nix-containers/ffmpeg:main \
  --owner kevinastone \
  --predicate-type https://spdx.dev/Document/v2.3
```
