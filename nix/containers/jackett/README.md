# `jackett`

- **Image**: `ghcr.io/kevinastone/nix-containers/jackett`
- **Recipe**: [default.nix](default.nix)
- **Tests**: [structure-test.yaml](structure-test.yaml)

A minimal, non-root (`65532:65532`) [Jackett](https://github.com/Jackett/Jackett) torrent indexer proxy container built from `nixpkgs`'s `jackett` package, modeled after [home-operations/containers](https://github.com/home-operations/containers/tree/main/apps/jackett). Runs `jackett --NoUpdates --DataFolder /config` on port `9117/tcp`.

## Configuration

Mount a persistent volume at `/config` for Jackett's `ServerConfig.json` and indexer configurations.

## Usage

```bash
docker run --rm -p 9117:9117 \
  -v ./jackett-config:/config \
  ghcr.io/kevinastone/nix-containers/jackett:main
```
