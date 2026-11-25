# Developer & AI Agent Guidelines (AGENTS.md)

Welcome! If you are an AI coding assistant (like Antigravity) or a developer onboarding to this repository, please read these instructions to understand the code architecture, tooling, and coding standards of `nix-containers`.

---

## 🛠️ Tooling & Commands

### 1. Code Formatting
`nix-containers` is fully Nix-integrated. To format the entire codebase, always run:
```bash
nix fmt
```

### 2. Building & Validating
To verify the flake config, checks, and formatting:
```bash
nix flake check
```

To build a specific OCI container image locally (which produces the symlink `./result` pointing to the built tarball):
```bash
nix build .#<container>
# e.g.:
nix build .#ffmpeg
```

### 3. Debugging & Inspecting
Enter the Nix devShell to load development tools like `dive`, `skopeo`, and custom helper scripts:
```bash
nix develop
```

Once in the devShell, you can inspect the OCI container layers using the `dive-archive` helper:
```bash
dive-archive ./result
```

### 4. Git Commits
Do **not** commit any code changes using `git commit` without explicitly asking and obtaining confirmation from the user first.

---

## 📁 Repository Structure

- `flake.nix`: Nix package definitions, auto-discovered container outputs, formatting rules, and devShell.
- `nix/lib/`:
  - `default.nix`: Exports shared Nix helpers (`containerTools`, also exposed via the flake's `lib` output).
  - `container-tools.nix`: Wraps `pkgs.dockerTools` with `buildImage` and `buildLayeredImage` helpers that inject standard OCI labels (`title`, `version`, `source`, `licenses`, `description`).
- `nix/containers/`:
  - `default.nix`: Auto-discovers all subdirectories containing a `default.nix` and calls them via `pkgs.callPackage` with `containerTools`.
  - `ffmpeg/`:
    - `default.nix`: OCI image derivation for `ffmpeg`.
    - `argo-ffmpeg-progress.sh`: Progress tracker script packaged into the `ffmpeg` container.
- `nix/scripts/`:
  - `push-multiarch.sh`: CI/CD helper script to assemble and push multi-architecture OCI manifests.
  - `default.nix`: Nix packaging expressions for shared CI and dev shell scripts (`push-multiarch`, `dive-archive`).
- `.github/workflows/`:
  - `ci.yaml`: CI/CD pipeline that validates the flake, auto-discovers containers from `flake.nix`, builds images for `amd64`/`arm64`, and publishes them to `ghcr.io/${{ github.repository }}/<container>`.
- `AGENTS.md`: Onboarding guidelines for developers and AI agents (this file).

---

## ➕ Adding a New Container

To add a new container (for example, `keycloak`):
1. Create `nix/containers/<name>/default.nix` using `containerTools.buildImage` (or `containerTools.buildLayeredImage`) with `name`, `tag`, and optional `description` (which automatically sets standard OCI labels including `org.opencontainers.image.source`).
2. Put any container-specific scripts or assets alongside it in `nix/containers/<name>/`.
3. Stage new files with `git add` so Nix Flakes includes them in evaluation.
4. Run `nix fmt` and `nix flake check`.
