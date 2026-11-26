# `ffmpeg`

- **Image**: `ghcr.io/kevinastone/nix-containers/ffmpeg`
- **Recipe**: [default.nix](default.nix)
- **Tests**: [structure-test.yaml](structure-test.yaml)
- **Variants**: [`ffmpeg-argo`](argo/README.md) — adds `bash`, `coreutils`, `jq`, and `argo-ffmpeg-progress` for Argo Workflows

A minimal, shell-less, non-root (`65532:65532`) [FFmpeg](https://ffmpeg.org/) container built from `nixpkgs`'s `ffmpeg-headless` package, satisfying the Kubernetes `restricted` Pod Security Standard.

## Usage

```bash
docker run --rm \
  -v "$PWD:/work" \
  ghcr.io/kevinastone/nix-containers/ffmpeg:main \
  -i /work/input.mkv -c:v libx264 -c:a aac /work/output.mp4
```
