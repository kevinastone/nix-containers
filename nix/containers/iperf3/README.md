# `iperf3`

- **Image**: `ghcr.io/kevinastone/nix-containers/iperf3`
- **Recipe**: [default.nix](default.nix)
- **Tests**: [structure-test.yaml](structure-test.yaml)

A minimal, non-root (`65532:65532`) [iperf3](https://software.es.net/iperf/) network throughput benchmark container built from `nixpkgs`'s `iperf3` package. Defaults to server mode (`iperf3 --server`) on port `5201` (`tcp`/`udp`); pass client arguments (e.g. `-c <host>`) to run one-off throughput tests.

## Usage

```bash
# Run as an iperf3 server
docker run --rm -p 5201:5201/tcp -p 5201:5201/udp \
  ghcr.io/kevinastone/nix-containers/iperf3:main

# Run as an iperf3 client
docker run --rm ghcr.io/kevinastone/nix-containers/iperf3:main -c 10.0.0.10
```
