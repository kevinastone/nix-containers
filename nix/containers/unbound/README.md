# `unbound`

- **Image**: `ghcr.io/kevinastone/nix-containers/unbound`
- **Recipe**: [default.nix](default.nix)
- **Tests**: [structure-test.yaml](structure-test.yaml)

A minimal, non-root (`65532:65532`), read-only-rootfs [Unbound](https://www.unbound.net) validating recursive DNS resolver built from `nixpkgs`'s `unbound` package. Ships with a ready-to-run `/etc/unbound/unbound.conf` configured on unprivileged port `5335` (`tcp`/`udp`), pre-wired with DNSSEC root trust anchors (`dns-root-data`) and CA certificates for DNS-over-TLS forwarding.

## Configuration

Drop configuration snippets (`*.conf`) into `/config` (loaded automatically via `include: "/config/*.conf"`), or mount a full `unbound.conf` directly at `/etc/unbound/unbound.conf`.

## Usage

```bash
docker run --rm \
  -p 5335:5335/tcp \
  -p 5335:5335/udp \
  -v ./unbound-conf.d:/config:ro \
  ghcr.io/kevinastone/nix-containers/unbound:main
```
