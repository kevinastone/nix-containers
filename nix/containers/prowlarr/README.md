# `prowlarr`

- **Image**: `ghcr.io/kevinastone/nix-containers/prowlarr`
- **Recipe**: [default.nix](default.nix)
- **Tests**: [structure-test.yaml](structure-test.yaml)

A minimal, non-root (`65532:65532`) [Prowlarr](https://prowlarr.com) container built from `nixpkgs`'s `prowlarr` package, modeled after [home-operations/containers](https://github.com/home-operations/containers/tree/main/apps/prowlarr). Runs `Prowlarr --nobrowser --data=/config` on port `9696` with in-app updates disabled (`PROWLARR__UPDATE__MECHANISM=External`).

## Configuration

Mount a persistent volume at `/config` for Prowlarr's database and configuration. Settings can also be configured via `PROWLARR__<SECTION>__<KEY>` environment variables.

## Usage

```bash
docker run --rm -p 9696:9696 \
  -v ./prowlarr-config:/config \
  ghcr.io/kevinastone/nix-containers/prowlarr:main
```
