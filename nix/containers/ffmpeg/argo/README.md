# `ffmpeg-argo`

- **Image**: `ghcr.io/kevinastone/nix-containers/ffmpeg-argo`
- **Base**: [`ffmpeg`](../README.md)
- **Recipe**: [default.nix](default.nix)
- **Tests**: [../structure-test.yaml](../structure-test.yaml), [structure-test.yaml](structure-test.yaml)

Extends the [`ffmpeg`](../README.md) container with `bash`, `coreutils`, `jq`, and the custom [`argo-ffmpeg-progress`](argo-ffmpeg-progress.sh) utility for [Argo Workflows](https://argoproj.github.io/workflows/) transcoding pipelines. Runs as numeric non-root user `65532:65532`.

## Using `argo-ffmpeg-progress`

`argo-ffmpeg-progress` consumes `ffmpeg`'s `-progress` stream from `stdin`, calculates the percentage completed based on total duration in seconds, and writes `<percent>/100` to a target progress file for Argo Workflows:

```bash
ffmpeg -i input.mp4 \
  -c:v libx264 \
  -progress >(argo-ffmpeg-progress 120 /tmp/argo-progress) \
  output.mp4
```

## Argo Workflows Integration

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
      image: ghcr.io/kevinastone/nix-containers/ffmpeg-argo:main
      command: [bash, -c]
      args:
        - |
          DURATION=3600 # 1 hour in seconds

          ffmpeg -i input.mkv \
            -c:v libx264 -c:a aac \
            -progress >(argo-ffmpeg-progress "$DURATION" /tmp/argo-progress) \
            output.mp4
```
