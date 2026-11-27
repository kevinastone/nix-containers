# `tautulli`

- **Image**: `ghcr.io/kevinastone/nix-containers/tautulli`
- **Recipe**: [default.nix](default.nix)
- **Tests**: [structure-test.yaml](structure-test.yaml)

A minimal, non-root (`65532:65532`) [Tautulli](https://tautulli.com) container built from `nixpkgs`'s `tautulli` package (with GitHub self-updates disabled), modeled after [home-operations/containers](https://github.com/home-operations/containers/tree/main/apps/tautulli). Runs `tautulli --nolaunch --datadir /config --config /config/config.ini` on port `8181/tcp`.

## Configuration

Mount a persistent volume at `/config` for Tautulli's `config.ini` and SQLite database.

## Usage

```bash
docker run --rm -p 8181:8181 \
  -v ./tautulli-config:/config \
  ghcr.io/kevinastone/nix-containers/tautulli:main
```
