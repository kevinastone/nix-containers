# `prometheus-nut-exporter`

- **Image**: [`ghcr.io/kevinastone/nix-containers/prometheus-nut-exporter`](https://ghcr.io/kevinastone/nix-containers/prometheus-nut-exporter)
- **Recipe**: [default.nix](default.nix)
- **Tests**: [structure-test.yaml](structure-test.yaml)

A minimal, non-root (`65532:65532`) [NUT Exporter](https://github.com/DRuggeri/nut_exporter) container built from `nixpkgs`'s `prometheus-nut-exporter` package. Exposes Prometheus metrics for Network UPS Tools (`upsd`) servers on port `9199`.

## Configuration

Configure the exporter using CLI flags (passed as container arguments) or environment variables:

- `NUT_EXPORTER_SERVER` / `--nut.server` (default: `127.0.0.1`)
- `NUT_EXPORTER_SERVERPORT` / `--nut.serverport` (default: `3493`)
- `NUT_EXPORTER_USERNAME` / `--nut.username`
- `NUT_EXPORTER_PASSWORD` (environment variable only)
- `NUT_EXPORTER_VARIABLES` / `--nut.vars_enable`

## Usage

```bash
docker run --rm -p 9199:9199 \
  -e NUT_EXPORTER_SERVER=nut.local \
  ghcr.io/kevinastone/nix-containers/prometheus-nut-exporter:main
```
