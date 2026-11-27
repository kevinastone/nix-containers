# `containerTools` Reference

Every container recipe under `nix/containers/<name>/default.nix` calls `containerTools.buildLayeredImage`, a typed `lib.evalModules` wrapper around `pkgs.dockerTools.buildLayeredImage` defined in [`nix/modules/container-tools/`](../nix/modules/container-tools/schema.nix).

---

## Minimal Example

```nix
{
  containerTools,
  prometheus-nut-exporter,
}:
containerTools.buildLayeredImage {
  name = "prometheus-nut-exporter";
  package = prometheus-nut-exporter;
  category = "monitoring";
  config = {
    ExposedPorts = {
      "9199/tcp" = { };
    };
  };
  structureTest = ./structure-test.yaml;
}
```

Passing `package` automatically derives `name` (`package.pname`), `tag` (`package.version`), `description` (`package.meta.description`), `licenses` (SPDX expression from `package.meta.license`), `meta.platforms` (intersected with `lib.platforms.linux`), `config.Entrypoint` (`[ (lib.getExe package) ]`), and includes `package` in the image contents.

---

## Options

### Metadata & Tagging

| Option | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `package` | `nullOr package` | `null` | Primary package used to derive defaults and runtime `Entrypoint`. |
| `name` | `str` | `package.pname` | OCI image repository name (`^[a-z0-9][a-z0-9._-]*$`, no `--`). |
| `tag` | `nonEmptyStr` | `package.version` | Primary OCI image version tag (expanded into SemVer tags in CI). |
| `category` | `enum` | `"utilities"` | Catalog grouping (`infrastructure`, `databases`, `networking`, `security`, `monitoring`, `media`, `utilities`). |
| `description` | `nullOr str` | `package.meta.description` | Sets `org.opencontainers.image.description` and catalog summary. |
| `source` | `nonEmptyStr` | Repo GitHub URL | Sets `org.opencontainers.image.source`. |
| `licenses` | `nullOr licenseType` | `package.meta.license` | SPDX string or Nixpkgs `lib.licenses` value(s) for `org.opencontainers.image.licenses`. |
| `extraTags` | `listOf str` | `[ ]` | Additional mutable tags published alongside SemVer tags and `:main`. |
| `features` | `listOf nonEmptyStr` | `[ ]` | Notable container traits or capabilities surfaced in the catalog `Features` column. |

### Users, Rootfs & Base Contents

| Option | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `runAsNonRoot` | `bool` | `true` | Configures a numeric `uid:gid` `Config.User`, creates `/etc/passwd` + `/etc/group` entries, and enables Kubernetes `restricted` PSS tests. |
| `readOnlyRoot` | `bool` | `true` | Declares read-only root filesystem compatibility and enforces `--read-only` in `restricted` PSS tests. |
| `user.name` | `nonEmptyStr` | `"nonroot"` | Primary non-root username when `runAsNonRoot = true`. |
| `user.uid` | `ints.positive` | `65532` | Primary numeric UID (`> 0`). |
| `user.gid` | `ints.positive` | `user.uid` | Primary numeric GID (`> 0`). |
| `user.home` | `nullOr str` | `"/home/${user.name}"` | Home directory created automatically and exported as `HOME` (unless `HOME` is overridden in `config.Env` or set to `null`). |
| `extraUsers.<name>` | `submodule` | `{ }` | Additional `/etc/passwd` + `/etc/group` users (`uid`, `gid`, `home`), e.g., privilege-dropping daemon accounts. |
| `dirs.<path>` | `submodule` | `{ }` | Declarative directories created in the image (`mode` default `"0755"`, `uid`/`gid` defaulting to the primary user or `0:0` when root). Writable `/tmp` (`1777`) is always created. |
| `includeCaCerts` | `bool` | `true` | Includes `dockerTools.caCertificates`. |
| `includeTzdata` | `bool` | `true` | Includes `tzdata` and sets `TZDIR` (unless overridden in `config.Env`). |
| `enableShell` | `bool` | `false` | Includes `bash`, `coreutils`, `/bin/sh`, and `/usr/bin/env`. |
| `contents` | `package` or `listOf package` | `[ ]` | Additional runtime packages included in the image layers. |
| `extraCommands` | `lines` | `""` | Shell commands run while assembling the customization layer. |
| `fakeRootCommands` | `lines` | `""` | Shell commands run under `fakeroot` (ownership/special permissions). |

Any extra attributes accepted by `pkgs.dockerTools.buildLayeredImage` (such as `maxLayers`) pass through automatically.

### Runtime `config`

`config` maps to the OCI Image Configuration `config` object:

- **Scalar fields** (`Entrypoint`, `Cmd`, `User`, `WorkingDir`, `StopSignal`): Override defaults directly.
- **Additive fields** (`Env`, `ExposedPorts`, `Volumes`, `Labels`): Merge across base and variant definitions. Duplicate `KEY=VALUE` entries in `Env` are deduplicated with the last definition winning.

### Testing (`structureTest` & `passthru.tests`)

- `structureTest` (`path` or `listOf path`, default `[ ]`): Runs [`container-structure-test`](https://github.com/GoogleContainerTools/container-structure-test). When `runAsNonRoot = true`, every `commandTests` entry (without root `setup`) is also re-executed under `--read-only --tmpfs /tmp --cap-drop=ALL --security-opt=no-new-privileges` to enforce Kubernetes `restricted` Pod Security Standard compatibility.
- `passthru.tests` (`attrsOf (nullOr package)`): Add custom test executables (`<bin> <runtime> <image>`) or set a built-in test (`oci`, `structure`, `restricted`) to `null` to disable it.

---

## Defining `variants`

`variants.<variant>` creates an image named `<name>-<variant>` (published to `ghcr.io/kevinastone/nix-containers/<name>-<variant>`) that inherits from the base image:

- **Inherited & overridable scalars**: `package`, `tag`, `category`, `description`, `licenses`, `runAsNonRoot`, `readOnlyRoot`, `user.*`, `includeCaCerts`, `includeTzdata`, `enableShell`, `config.{Entrypoint,Cmd,User,WorkingDir,StopSignal}`, `dirs.<path>.*`, and `config.Labels.<key>` inherit via `lib.mkDefault`, so variants can override any of them directly without `lib.mkForce`.
- **Merged collections**: `contents`, `features`, `structureTest`, `extraTags`, `dirs`, `extraUsers`, `extraCommands`, `fakeRootCommands`, `config.{Env,ExposedPorts,Volumes,Labels}`, and `passthru.tests` merge automatically with the base image. (Use `lib.mkForce` in a variant only if you want to discard inherited list items.)

```nix
{
  callPackage,
  containerTools,
  ffmpeg-headless,
}:
containerTools.buildLayeredImage {
  name = "ffmpeg";
  package = ffmpeg-headless;
  category = "media";
  description = "Minimal headless FFmpeg container";
  structureTest = ./structure-test.yaml;

  variants.argo = callPackage ./argo { };
}
```
