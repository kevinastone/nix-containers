# `ffmpeg` & `ffmpeg-argo`

- **Images**:
  - `ghcr.io/kevinastone/nix-containers/ffmpeg` — minimal, shell-less `ffmpeg-headless` container
  - `ghcr.io/kevinastone/nix-containers/ffmpeg-argo` — adds `bash`, `coreutils`, `jq`, and `argo-ffmpeg-progress` for Argo Workflows
- **Recipes**: [default.nix](default.nix), [argo/default.nix](argo/default.nix)
- **Tests**: [structure-test.yaml](structure-test.yaml), [argo/structure-test.yaml](argo/structure-test.yaml)

## Variants

| Image | Shell | Included Packages | Use Case |
| --- | --- | --- | --- |
| `ffmpeg` | No (`enableShell = false`) | `ffmpeg-headless` | General-purpose transcoding and media probing |
| `ffmpeg-argo` | Yes (`bash`, `coreutils`) | `ffmpeg-headless`, `jq`, `argo-ffmpeg-progress` | Cloud-native transcoding pipelines in Argo Workflows |

Both images run as numeric non-root user `65532:65532` and satisfy the Kubernetes `restricted` Pod Security Standard.

## Using `argo-ffmpeg-progress` (`ffmpeg-argo`)

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
