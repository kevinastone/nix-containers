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
  - [`ffmpeg`](#ffmpeg)
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

### `ffmpeg`

- **Image**: `ghcr.io/kevinastone/nix-containers/ffmpeg`
- **Recipe**: [nix/containers/ffmpeg/default.nix](nix/containers/ffmpeg/default.nix)

A minimal `ffmpeg` container designed for cloud-native transcoding pipelines (such as Argo Workflows). Includes `ffmpeg-headless`, `bash`, `jq`, `coreutils`, and the custom `argo-ffmpeg-progress` utility.

#### Using `argo-ffmpeg-progress`

`argo-ffmpeg-progress` consumes `ffmpeg`'s `-progress` stream from `stdin`, calculates the percentage completed based on total duration, and writes `<percent>/100` to a target file for Argo Workflows:

```bash
ffmpeg -i input.mp4 \
  -c:v libx264 \
  -progress >(argo-ffmpeg-progress 120 /tmp/argo-progress) \
  output.mp4
```

#### Argo Workflows Integration

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: transcode-video-
spec:
  entrypoint: transcode-step
  templates:
  - name: transcode-step
    progressFile: "/tmp/argo-progress"
    container:
      image: ghcr.io/kevinastone/nix-containers/ffmpeg:main
      command: [bash, -c]
      args:
        - |
          DURATION=3600 # 1 hour in seconds

          ffmpeg -i input.mkv \
            -c:v libx264 -c:a aac \
            -progress >(argo-ffmpeg-progress "$DURATION" /tmp/argo-progress) \
            output.mp4
```

---

## ➕ Adding a New Container

1. Create a new directory under `nix/containers/<name>/` with a `default.nix` using `containerTools.buildImage` (or `containerTools.buildLayeredImage`), passing `name`, `tag`, and optional `description` — standard OCI labels like `org.opencontainers.image.source` are applied automatically.
2. Stage the new files with `git add` (required so Nix Flakes sees them).
3. Run `nix fmt` and `nix flake check`.
4. Test building locally with `nix build .#<name>`.

`nix/containers/default.nix` automatically discovers all subdirectories containing a `default.nix`, exposes them as flake packages, and registers them in `lib.<system>.containers` for GitHub Actions.

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

The GitHub Actions workflow defined in [.github/workflows/ci.yaml](.github/workflows/ci.yaml) automates validation and deployment:

1. **Linting & Discovery**: Runs `nix flake check` and evaluates `.#lib.x86_64-linux.containers` to discover all container targets.
2. **Build Matrix**: Spawns `amd64` and `arm64` runners for each discovered container.
3. **Upstream Tagging**: Extracts each container's `.imageTag` directly from Nix to tag the published image alongside the branch tag.
4. **Multi-Arch Push**: Combines architecture builds into a multi-arch manifest using `push-multiarch` and publishes to `ghcr.io/<owner>/<repo>/<container>`.
