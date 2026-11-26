arch := arch()
linux_system := arch + "-linux"

[private]
default:
    @just --list

# Format the repository with treefmt
fmt:
    nix fmt

# Run flake checks and formatting validation
check:
    nix flake check

# Regenerate the README.md container catalog table
readme:
    nix run .#update-readme

# Update flake inputs and custom packages
update:
    nix flake update
    nix run .#update-packages

# Pin GitHub Actions to full commit SHAs
pin:
    pinact run .github/workflows/*.yaml .github/actions/*/*.yml

# Scaffold a new container, track files, sync README.md, and format
new name *args:
    new-container {{ name }} {{ args }}
    jj status
    nix run .#update-readme
    nix fmt

# Build a container image tarball into ./result
build name:
    nix build .#packages.{{ linux_system }}.{{ name }} --out-link result -L

# Build a container image and run its test suite + dive CI layer check
test name: (build name)
    nix run .#containerTests.{{ name }} -- ./result
    dive-archive ./result --ci

# Build a container image, generate an SBOM, and scan for vulnerabilities
scan name *args: (build name)
    scan-image ./result --label {{ name }} {{ args }}

# Build a container image and inspect layers interactively in dive
dive name *args: (build name)
    dive-archive ./result {{ args }}

# Inspect a container derivation's dependency tree in nix-tree
inspect name:
    nix-tree --derivation .#packages.{{ linux_system }}.{{ name }}
