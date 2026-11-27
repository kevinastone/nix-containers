# `calibre-web`

- **Image**: `ghcr.io/kevinastone/nix-containers/calibre-web`
- **Recipe**: [default.nix](default.nix)
- **Tests**: [structure-test.yaml](structure-test.yaml)

A minimal, non-root (`65532:65532`) [Calibre-Web](https://github.com/janeczku/calibre-web) container built from `nixpkgs`'s `calibre-web` package (patched to log to `/dev/stdout` for read-only rootfs compatibility). Runs `calibre-web -p /config/app.db -g /config/gdrive.db` on port `8083/tcp`.

## Configuration

Mount a persistent volume at `/config` for `app.db` and at `/books` for your Calibre library (`metadata.db` and eBook files). Set `CALIBRE_PORT` to override the default listen port (`8083`), or `CACHE_DIRECTORY` (defaults to `/tmp`) to persist cover thumbnails.

## Usage

```bash
docker run --rm -p 8083:8083 \
  -v ./calibre-web-config:/config \
  -v /path/to/calibre-library:/books \
  ghcr.io/kevinastone/nix-containers/calibre-web:main
```
