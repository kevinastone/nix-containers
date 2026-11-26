# `radarr`

- **Image**: `ghcr.io/kevinastone/nix-containers/radarr`
- **Recipe**: [default.nix](default.nix)
- **Tests**: [structure-test.yaml](structure-test.yaml)

A minimal, non-root (`65532:65532`) [Radarr](https://radarr.video) container built from `nixpkgs`'s `radarr` package (including `ffprobe` and `sqlite`), modeled after [home-operations/containers](https://github.com/home-operations/containers/tree/main/apps/radarr). Runs `Radarr --nobrowser --data=/config` on port `7878` with in-app updates disabled (`RADARR__UPDATE__MECHANISM=External`).

## Configuration

Mount a persistent volume at `/config` for Radarr's database and configuration, and mount your media/download paths as needed. Settings can also be configured via `RADARR__<SECTION>__<KEY>` environment variables.

## Usage

```bash
docker run --rm -p 7878:7878 \
  -v ./radarr-config:/config \
  -v /path/to/movies:/movies \
  -v /path/to/downloads:/downloads \
  ghcr.io/kevinastone/nix-containers/radarr:main
```
