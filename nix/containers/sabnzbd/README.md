# `sabnzbd`

- **Image**: `ghcr.io/kevinastone/nix-containers/sabnzbd`
- **Recipe**: [default.nix](default.nix)
- **Tests**: [structure-test.yaml](structure-test.yaml)

A minimal, non-root (`65532:65532`) [SABnzbd](https://sabnzbd.org) container built from `nixpkgs`'s `sabnzbd` package (including `par2cmdline-turbo`, `unrar` under RARLAB's `unfreeRedistributable` license, `unzip`, and `p7zip`), modeled after [home-operations/containers](https://github.com/home-operations/containers/tree/main/apps/sabnzbd). Runs `sabnzbd --browser 0 --server [::]:8080 --config-file /config/sabnzbd.ini --console` on port `8080/tcp`.

## Configuration

Mount a persistent volume at `/config` for `sabnzbd.ini` and queue state, and mount your download paths as needed.

## Usage

```bash
docker run --rm -p 8080:8080 \
  -v ./sabnzbd-config:/config \
  -v /path/to/downloads:/downloads \
  ghcr.io/kevinastone/nix-containers/sabnzbd:main
```
