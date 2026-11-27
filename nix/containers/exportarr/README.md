# `exportarr`

- **Image**: `ghcr.io/kevinastone/nix-containers/exportarr`
- **Recipe**: [default.nix](default.nix)
- **Tests**: [structure-test.yaml](structure-test.yaml)

A minimal, non-root (`65532:65532`) [Exportarr](https://github.com/onedr0p/exportarr) Prometheus exporter container built from `nixpkgs`'s `exportarr` package. Supports `sonarr`, `radarr`, `lidarr`, `prowlarr`, `bazarr`, and `sabnzbd` subcommands on port `9707/tcp`.

## Configuration

Pass the target application subcommand (`sonarr`, `radarr`, `lidarr`, `prowlarr`, `bazarr`, or `sabnzbd`) as the container command/argument, and configure `URL` and `APIKEY` (or `API_KEY_FILE`) via environment variables.

## Usage

```bash
docker run --rm -p 9707:9707 \
  -e URL=http://sonarr:8989 \
  -e APIKEY=your-api-key \
  ghcr.io/kevinastone/nix-containers/exportarr:main sonarr
```
