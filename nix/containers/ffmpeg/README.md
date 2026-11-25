# `ffmpeg`

- **Image**: `ghcr.io/kevinastone/nix-containers/ffmpeg`
- **Recipe**: [default.nix](default.nix)
- **Tests**: [test.yaml](test.yaml)

A minimal, non-root (`65532:65532`) `ffmpeg` container designed for cloud-native transcoding pipelines (such as Argo Workflows). Includes `ffmpeg-headless`, `bash`, `jq`, `coreutils`, and the custom `argo-ffmpeg-progress` utility.

## Using `argo-ffmpeg-progress`

`argo-ffmpeg-progress` consumes `ffmpeg`'s `-progress` stream from `stdin`, calculates the percentage completed based on total duration, and writes `<percent>/100` to a target file for Argo Workflows:

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
