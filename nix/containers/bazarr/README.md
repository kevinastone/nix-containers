# `bazarr`

- **Image**: `ghcr.io/kevinastone/nix-containers/bazarr`
- **Recipe**: [default.nix](default.nix)
- **Tests**: [structure-test.yaml](structure-test.yaml)

A minimal, non-root (`65532:65532`) [Bazarr](https://www.bazarr.media) container built from `nixpkgs`'s `bazarr` package (with `ffmpeg-headless` and `unar`), modeled after [home-operations/containers](https://github.com/home-operations/containers/tree/main/apps/bazarr). Supervised by `tini` with `SIGINT` process-group forwarding (`StopSignal = "SIGINT"`) and runs `bazarr --no-update --config /config` on port `6767/tcp`.

## Configuration

Mount a persistent volume at `/config` for Bazarr's `config.yaml`, SQLite database, and cache, and mount your media paths matching Sonarr/Radarr. Settings can also be configured declaratively via `DYNACONF_<SECTION>__<KEY>` environment variables.

## Usage

```bash
docker run --rm -p 6767:6767 \
  -v ./bazarr-config:/config \
  -v /path/to/movies:/movies \
  -v /path/to/tv:/tv \
  ghcr.io/kevinastone/nix-containers/bazarr:main
```
