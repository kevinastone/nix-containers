# `dnsdist`

- **Image**: `ghcr.io/kevinastone/nix-containers/dnsdist`
- **Recipe**: [default.nix](default.nix)
- **Tests**: [structure-test.yaml](structure-test.yaml)

A minimal, non-root (`65532:65532`) [dnsdist](https://dnsdist.org) DNS load balancer container built from `nixpkgs`'s `dnsdist` package (with DNS-over-HTTPS, DNS-over-TLS, DNSCrypt, DNSTAP, YAML configuration, and eBPF/AF_XDP support enabled). Runs `dnsdist --supervised --disable-syslog --config /etc/dnsdist/dnsdist.conf`.

## Configuration

Mount your Lua (`dnsdist.conf`) or YAML (`dnsdist.yml`, passing `--config /etc/dnsdist/dnsdist.yml`) configuration into `/etc/dnsdist/`. When running without `CAP_NET_BIND_SERVICE` in restricted Kubernetes pods, bind an unprivileged listen port (e.g. `setLocal("0.0.0.0:5300")`) and map your `Service` port `53` to `targetPort: 5300`.

## Usage

```bash
docker run --rm \
  -p 5300:5300/tcp \
  -p 5300:5300/udp \
  -v ./dnsdist.conf:/etc/dnsdist/dnsdist.conf:ro \
  ghcr.io/kevinastone/nix-containers/dnsdist:main
```
