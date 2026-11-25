def linux-system [arch: string]: nothing -> string {
    let a = if $arch != "" { $arch } else { $nu.os-info.arch }
    match $a {
        "amd64" | "x86_64" => "x86_64-linux"
        "arm64" | "aarch64" => "aarch64-linux"
        _ => $"($a)-linux"
    }
}

def render-nvd-section [
    base_dir: string
    system: string
    container: string
    head_closure: string
]: nothing -> list<string> {
    if $base_dir == "" or not ($base_dir | path exists) {
        return []
    }

    let base_flake = $"path:($base_dir | path expand)"
    let attr = $"packages.($system).($container)"
    let head_drv = (^nix eval --raw $".#($attr).drvPath" | str trim)
    let base_drv_res = (^nix eval --raw $"($base_flake)#($attr).drvPath" | complete)

    if $base_drv_res.exit_code != 0 {
        return [
            ""
            "> _New container (not yet present on `main`)._"
        ]
    }

    if ($base_drv_res.stdout | str trim) == $head_drv {
        return []
    }

    let base_closure = (
        ^nix build $"($base_flake)#($attr).closure" --no-link --print-out-paths | str trim
    )
    let diff = (^nvd --color never diff $base_closure $head_closure | str trim)

    [
        ""
        "<details>"
        "<summary>Runtime package diff vs <code>main</code> (<code>nvd</code>)</summary>"
        ""
        "```text"
        $diff
        "```"
        ""
        "</details>"
    ]
}

# Inspect a built container archive (`dive --ci`, sizes, top runtime store paths, and optional `nvd` diff).
def main [
    archive: path = "./result" # Path to the built image archive (.tar.gz or .tar)
    --container: string # Container name (e.g. ffmpeg)
    --arch: string = "" # Target architecture (amd64 or arm64; defaults to host arch)
    --base-dir: string = "" # Optional baseline flake checkout (e.g. main worktree) for `nvd` diff
] {
    if $container == null or $container == "" {
        error make {msg: "--container is required"}
    }

    let real_archive = $archive | path expand
    if not ($real_archive | path exists) {
        error make {msg: $"Image archive not found: ($real_archive)"}
    }

    let system = (linux-system $arch)
    let compressed_size = ls $real_archive | get 0.size | into string

    let tmp_dir = (mktemp -d)
    let report = try {
        let dive_json = $tmp_dir | path join "dive.json"
        ^dive-archive $real_archive --json $dive_json
        ^dive-archive $real_archive --ci

        let dive_data = (open $dive_json)
        let uncompressed_size = $dive_data.image.sizeBytes | into filesize | into string
        let wasted_size = $dive_data.image.inefficientBytes | into filesize | into string
        let efficiency_pct = $dive_data.image.efficiencyScore * 100 | math round --precision 1
        let layer_count = $dive_data.layer | length

        let closure = (
            ^nix build $".#packages.($system).($container).closure" --no-link --print-out-paths
            | str trim
        )
        let store_paths = (
            open $"($closure)/store-paths"
            | lines
            | where { ($in !~ '-closure-info$') and ($in !~ '-config\.json$') }
        )
        let top_deps = (
            ^nix path-info -sSh ...$store_paths
            | lines
            | reverse
            | first 15
            | str join "\n"
        )

        let title = if $arch != "" { $"`($container)` \(`($arch)`\)" } else { $"`($container)`" }

        [
            $"## 📦 ($title)"
            ""
            "| Metric | Value |"
            "| --- | --- |"
            $"| Compressed Archive | `($compressed_size)` |"
            $"| Uncompressed Image | `($uncompressed_size)` |"
            $"| Layers | `($layer_count)` |"
            $"| Layer Efficiency \(`dive --ci`\) | `($efficiency_pct)%` \(`($wasted_size)` wasted\) |"
            $"| Runtime Store Paths | `($store_paths | length)` |"
            ""
            "<details>"
            "<summary>Top runtime store dependencies (<code>nix path-info -sSh</code>)</summary>"
            ""
            "```text"
            $top_deps
            "```"
            ""
            "</details>"
            ...(render-nvd-section $base_dir $system $container $closure)
            ""
        ]
        | str join "\n"
    } finally {
        rm -rf $tmp_dir
    }

    print $report

    let summary_path = $env.GITHUB_STEP_SUMMARY? | default ""
    if $summary_path != "" {
        $report | save --append $summary_path
    }
}
