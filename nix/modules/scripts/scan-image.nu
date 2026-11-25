# Generate an SPDX SBOM with Syft (`nix-cataloger`) and scan for CVEs with Grype.
def main [
    archive: path = "./result" # Path to the built image archive (.tar.gz or .tar)
    --sbom-output: path # Optional output path for SPDX JSON SBOM
    --label: string = "" # Optional label for the GitHub Actions step summary heading
] {
    let archive = $archive | path expand
    if not ($archive | path exists) {
        error make {msg: $"Image archive not found: ($archive)"}
    }

    let tmp_dir = (mktemp -d)
    try {
        let tmp_tar = $tmp_dir | path join "image.tar"
        let tmp_syft = $tmp_dir | path join "sbom.syft.json"

        ^gzip -cdf $archive | save --raw --force $tmp_tar

        let outputs = [
            "-o" $"syft-json=($tmp_syft)"
            ...(
                if $sbom_output != null { ["-o" $"spdx-json=($sbom_output | path expand)"] } else { [] }
            )
        ]
        ^syft scan $"docker-archive:($tmp_tar)" ...$outputs -q

        let pkg_count = (
            open $tmp_syft
            | get -o artifacts
            | default []
            | length
        )
        let scan_out = (^grype $"sbom:($tmp_syft)" --by-cve -q | str trim)
        let title = if $label != "" {
            $label
        } else {
            $archive | path basename
        }

        print $"Cataloged ($pkg_count) packages in ($title)"
        print $scan_out

        let summary_path = $env.GITHUB_STEP_SUMMARY? | default ""
        if $summary_path != "" {
            [
                $"### Vulnerability Scan: `($title)`"
                ""
                $"Cataloged **($pkg_count)** packages via Syft \(`nix-cataloger`\)."
                ""
                "```text"
                $scan_out
                "```"
                ""
            ]
            | str join "\n"
            | save --append $summary_path
        }
    } finally {
        rm -rf $tmp_dir
    }
}
