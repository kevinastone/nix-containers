# `sonarr`

- **Image**: `ghcr.io/kevinastone/nix-containers/sonarr`
- **Recipe**: [default.nix](default.nix)
- **Tests**: [structure-test.yaml](structure-test.yaml)

A minimal, non-root (`65532:65532`) [Sonarr](https://sonarr.tv) container built from `nixpkgs`'s `sonarr` package (including `ffprobe` and `sqlite`), modeled after [home-operations/containers](https://github.com/home-operations/containers/tree/main/apps/sonarr). Runs `Sonarr --nobrowser --data=/config` on port `8989` with in-app updates disabled (`SONARR__UPDATE__MECHANISM=External`).

## Configuration

Mount a persistent volume at `/config` for Sonarr's database and configuration, and mount your media/download paths as needed. Settings can also be configured via `SONARR__<SECTION>__<KEY>` environment variables.

## Usage

```bash
docker run --rm -p 8989:8989 \
  -v ./sonarr-config:/config \
  -v /path/to/tv:/tv \
  -v /path/to/downloads:/downloads \
  ghcr.io/kevinastone/nix-containers/sonarr:main
```
