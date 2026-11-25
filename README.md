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
  - [Building an Image](#building-an-image)
  - [Debugging Layer Efficiency](#debugging-layer-efficiency)
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
| [`ffmpeg`](nix/containers/ffmpeg/README.md) | `ghcr.io/kevinastone/nix-containers/ffmpeg` | `linux/amd64`, `linux/arm64` | Minimal ffmpeg container with Argo Workflows progress reporting ([recipe](nix/containers/ffmpeg/default.nix)) |
| [`keycloak`](nix/containers/keycloak/README.md) | `ghcr.io/kevinastone/nix-containers/keycloak` | `linux/amd64`, `linux/arm64` | Identity and access management for modern applications and services ([recipe](nix/containers/keycloak/default.nix)) |
| [`nut`](nix/containers/nut/README.md) | `ghcr.io/kevinastone/nix-containers/nut` | `linux/amd64`, `linux/arm64` | Network UPS Tools ([recipe](nix/containers/nut/default.nix)) |
<!-- END:CONTAINER_CATALOG -->

---

## ➕ Adding a New Container

1. Create a new directory under `nix/containers/<name>/` with a `default.nix` using `containerTools.buildLayeredImage` (or `containerTools.buildImage`). Pass `package` to automatically derive `name`, `tag`, `description`, `config.Entrypoint`, and package inclusion (any of which can be overridden). Non-root user (`65532:65532`), `caCertificates`, `tzdata`, writable `/tmp`, and standard OCI labels like `org.opencontainers.image.source` are applied automatically (and `enableShell = true` adds `bash` + `coreutils`).
2. (Optional) Add a `nix/containers/<name>/test.yaml` (`container-structure-test` config) and pass `structureTest = ./test.yaml;` to verify runtime behavior, commands, and metadata in CI before publishing (every container also gets `passthru.tests.oci` and, when `runAsNonRoot = true`, `passthru.tests.restricted` automatically).
3. Stage the new files with `git add` (required so Nix Flakes sees them).
4. Run `nix fmt` and `nix flake check`.
5. Test building locally with `nix build .#<name>` (and `nix run .#<name>.test -- ./result` on Linux).

`nix/modules/containers.nix` automatically discovers all subdirectories under `nix/containers/` containing a `default.nix`, exposes them as flake packages on their supported platforms, and computes `lib.ci` for GitHub Actions.

---

## 💻 Local Development

### Nix DevShell

Enter the development shell to load utility packages (`dive`, `skopeo`, `dive-archive`) automatically:

```bash
nix develop
```

### Building an Image

To build an OCI container tarball locally for your host architecture:

```bash
nix build .#ffmpeg
```

This creates a symlink `result` pointing to the output tarball.

### Debugging Layer Efficiency

Use the custom `dive-archive` script loaded by `nix develop` to inspect the container layers of your local build:

```bash
dive-archive ./result
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
```
