# `keycloak`

- **Image**: `ghcr.io/kevinastone/nix-containers/keycloak`
- **Recipe**: [default.nix](default.nix)
- **Tests**: [test.yaml](test.yaml)

A minimal, non-root (`65532:65532`) Keycloak container matching the upstream `/opt/keycloak` layout (`/opt/keycloak/bin/kc.sh` entrypoint, `start --optimized` default command, writable `conf`/`data`/`providers`/`themes` directories, and ports `8080`, `8443`, and `9000` exposed), pre-augmented at build time with:

- `db=postgres`
- `health-enabled=true`
- `metrics-enabled=true`
- `http-metrics-histograms-enabled=true`
- `event-metrics-user-enabled=true`

## Usage

```bash
docker run --rm -p 8080:8080 -p 9000:9000 \
  -e KC_DB_URL=jdbc:postgresql://postgres:5432/keycloak \
  -e KC_DB_USERNAME=keycloak \
  -e KC_DB_PASSWORD=keycloak \
  -e KC_BOOTSTRAP_ADMIN_USERNAME=admin \
  -e KC_BOOTSTRAP_ADMIN_PASSWORD=admin \
  ghcr.io/kevinastone/nix-containers/keycloak:main
```
