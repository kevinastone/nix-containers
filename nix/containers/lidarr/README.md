# `lidarr`

- **Image**: `ghcr.io/kevinastone/nix-containers/lidarr`
- **Recipe**: [default.nix](default.nix)
- **Tests**: [structure-test.yaml](structure-test.yaml)

A minimal, non-root (`65532:65532`) [Lidarr](https://lidarr.audio) container built from `nixpkgs`'s `lidarr` package (including `chromaprint` `fpcalc` and `sqlite`), modeled after [home-operations/containers](https://github.com/home-operations/containers/tree/main/apps/lidarr). Runs `Lidarr --nobrowser --data=/config` on port `8686` with in-app updates disabled (`LIDARR__UPDATE__MECHANISM=External`).

## Configuration

Mount a persistent volume at `/config` for Lidarr's database and configuration, and mount your music/download paths as needed. Settings can also be configured via `LIDARR__<SECTION>__<KEY>` environment variables.

## Usage

```bash
docker run --rm -p 8686:8686 \
  -v ./lidarr-config:/config \
  -v /path/to/music:/music \
  -v /path/to/downloads:/downloads \
  ghcr.io/kevinastone/nix-containers/lidarr:main
```
