# `qbittorrent`

- **Image**: `ghcr.io/kevinastone/nix-containers/qbittorrent`
- **Recipe**: [default.nix](default.nix)
- **Tests**: [structure-test.yaml](structure-test.yaml)

A minimal, non-root (`65532:65532`) [qBittorrent](https://www.qbittorrent.org) container built from `nixpkgs`'s headless `qbittorrent-nox` package, modeled after [home-operations/containers](https://github.com/home-operations/containers/tree/main/apps/qbittorrent). Exposes the WebUI on port `8080/tcp` and BitTorrent on `6881/tcp` and `6881/udp`, with `QBT_CONFIRM_LEGAL_NOTICE=1` and XDG paths pointed at `/config`.

## Configuration

Mount a persistent volume at `/config` for qBittorrent's configuration and session state, and mount your download path as needed. Native `QBT_*` environment variables (such as `QBT_WEBUI_PORT` and `QBT_TORRENTING_PORT`) are supported directly by `qbittorrent-nox`.

## Usage

```bash
docker run --rm \
  -p 8080:8080 \
  -p 6881:6881/tcp \
  -p 6881:6881/udp \
  -v ./qbittorrent-config:/config \
  -v /path/to/downloads:/downloads \
  ghcr.io/kevinastone/nix-containers/qbittorrent:main
```
