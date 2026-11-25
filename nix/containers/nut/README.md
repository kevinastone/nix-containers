# `nut`

- **Image**: `ghcr.io/kevinastone/nix-containers/nut`
- **Recipe**: [default.nix](default.nix)
- **Tests**: [structure-test.yaml](structure-test.yaml)

A minimal Network UPS Tools (NUT) server container built from `nixpkgs`'s `nut` package (including USB HID, SNMP, IPMI, and serial drivers). Starts configured UPS drivers via `upsdrvctl` and runs `upsd` in the foreground on port `3493` with graceful `SIGTERM` cleanup.

## Configuration

Mount your NUT configuration files (`nut.conf`, `ups.conf`, `upsd.conf`, `upsd.users`) into `/etc/nut`:

- `NUT_CONFPATH=/etc/nut`
- `NUT_STATEPATH=/var/run/nut`
- `NUT_USER=root` (default for USB device access; override to `nutmon` if USB device permissions allow non-root access)

## Usage

```bash
docker run --rm -p 3493:3493 \
  --device /dev/bus/usb \
  -v ./nut-config:/etc/nut:ro \
  ghcr.io/kevinastone/nix-containers/nut:main
```
