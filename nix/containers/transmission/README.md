# `transmission`

- **Image**: `ghcr.io/kevinastone/nix-containers/transmission`
- **Recipe**: [default.nix](default.nix)
- **Tests**: [structure-test.yaml](structure-test.yaml)

A minimal, non-root (`65532:65532`) [Transmission](https://transmissionbt.com) BitTorrent daemon container built from `nixpkgs`'s headless `transmission_4` package (including the WebUI and `transmission-remote`). Runs `transmission-daemon --foreground --config-dir /config`, exposing the RPC/WebUI on `9091/tcp` and BitTorrent peer traffic on `51413/tcp` and `51413/udp`.

## Configuration

Mount a persistent volume at `/config` for `settings.json`, resume files, and torrents, and mount your download path as needed. Additional `transmission-daemon` flags (such as `--rpc-bind-address 0.0.0.0` or `--allowed *`) can be appended to the container command or configured in `/config/settings.json`.

## Usage

```bash
docker run --rm \
  -p 9091:9091 \
  -p 51413:51413/tcp \
  -p 51413:51413/udp \
  -v ./transmission-config:/config \
  -v /path/to/downloads:/downloads \
  ghcr.io/kevinastone/nix-containers/transmission:main
```
