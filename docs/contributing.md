# Contributing & Local Development

This guide covers local development, scaffolding new containers, authoring variants, and running tests in `nix-containers`.

---

## Nix DevShell

Enter the development shell (or allow `.envrc` via `direnv`) to load `just`, `new-container`, `update-readme`, `inspect-image`, `scan-image`, `dive`, `dive-archive`, `nix-tree`, `nvd`, `regctl`, `skopeo`, `cosign`, `container-structure-test`, and `nushell`:

```bash
nix develop
just --list
```

---

## Adding a New Container

Inside `nix develop`, scaffold a new container with `just`:

```bash
just new <name>
# or customize the nixpkgs attribute and catalog category:
just new <name> --package <nixpkgs-attr> --category <category>
```

Valid `category` values: `infrastructure`, `databases`, `networking`, `security`, `monitoring`, `media`, `utilities` (default).

`just new` creates `nix/containers/<name>/` (`default.nix`, `structure-test.yaml`, and `README.md`), syncs the root [README.md](../README.md) catalog, and formats the repository:

1. **Customize `nix/containers/<name>/default.nix`** using `containerTools.buildLayeredImage` (see the [`containerTools` Reference](container-tools.md)).
2. **Add runtime assertions in `nix/containers/<name>/structure-test.yaml`** (`container-structure-test`). Every container automatically receives an OCI metadata check (`oci`) and, when `runAsNonRoot = true`, a Kubernetes `restricted` Pod Security Standard check (`restricted`).
3. **Document usage in `nix/containers/<name>/README.md`** (ports, volumes, environment variables, and Docker/Kubernetes examples).
4. **Sync and validate:**
   ```bash
   just readme   # Sync README.md catalog if description, version, user, or category changed
   just fmt      # Run treefmt (nixfmt, statix, deadnix, nufmt, yamlfmt, shellcheck, typos, etc.)
   just check    # Run nix flake check
   ```

---

## Baseline vs. Variant Guidelines

To keep images predictable for external consumers:

1. **`<name>` is always the minimal, general-purpose default.**
   - Keep `runAsNonRoot = true` (`65532:65532`) unless the software strictly requires root privileges (such as hardware USB daemons).
   - Keep `enableShell = false` unless the upstream entrypoint itself requires `/bin/sh`.
   - Preserve the standard upstream `Entrypoint` and avoid bundling workflow-engine-specific glue scripts in the base image.
2. **Use `variants.<variant>` (`<name>-<variant>`) for specialized roles or package flavors.**
   - **Trivial variants** (e.g., swapping `package` or toggling a flag) can be defined inline in `nix/containers/<name>/default.nix`.
   - **Self-contained variants** with their own scripts, dependencies, or tests should live in `nix/containers/<name>/<variant>/` (`default.nix`, `structure-test.yaml`, scripts, and optional `README.md`) and be wired via `variants.<variant> = callPackage ./<variant> { };` (see [`nix/containers/ffmpeg/`](../nix/containers/ffmpeg/default.nix) as the reference layout).
   - Avoid `-debug` / `-dev` variants—Kubernetes ephemeral debug containers (`kubectl debug`) handle interactive troubleshooting without multiplying the CI matrix.

---

## Building, Testing & Debugging

`just` recipes automatically resolve the matching Linux container derivation (`.#packages.<arch>-linux.<name>`), working on both Linux and macOS (with a configured Linux builder + Docker/Podman/OrbStack):

```bash
# Build OCI archive into ./result
just build ffmpeg

# Build image, run oci + structure + restricted tests, and verify dive --ci efficiency
just test ffmpeg
just test ffmpeg-argo

# Generate SPDX SBOM (Syft nix-cataloger) and scan for CVEs (Grype)
just scan ffmpeg
```

On Linux, you can also invoke Nix directly:

```bash
nix build .#ffmpeg
nix run .#ffmpeg.test -- ./result
```

### Layer Efficiency & Dependency Inspection

Inspect OCI layers interactively in `dive` or trace why a store path is pulled into the runtime closure with `nix-tree`:

```bash
just dive ffmpeg
just inspect ffmpeg
```
