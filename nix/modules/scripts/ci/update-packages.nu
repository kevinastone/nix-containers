# Update locally defined custom packages in the flake via nix-update with per-package fault isolation.
def main [
    ...packages: string # Specific package names to update (defaults to all flake.lib.updatePackageSpecs)
] {
    let all_specs = (^nix eval --json .#lib.updatePackageSpecs | from json)
    let specs = if ($packages | is-empty) {
        $all_specs
    } else {
        $packages
        | each {|name|
            let found = $all_specs | where name == $name
            if ($found | is-empty) {
                {name: $name, args: []}
            } else {
                $found.0
            }
        }
    }

    if ($specs | is-empty) {
        print "No custom packages to update."
        return
    }

    let system = (linux-system)

    # Nix 2.35+ `nix flake metadata` does not materialize the flake store path on disk;
    # force realization so `nix-update --flake` can evaluate it via `nix-instantiate`.
    ^nix eval --raw --impure --expr '(builtins.getFlake ("git+file://" + toString ./.)).outPath' | ignore

    mut succeeded = 0
    mut failures = []

    for spec in $specs {
        print $"Updating ($spec.name)..."
        let attr = $"legacyPackages.($system).updatePackages.($spec.name)"
        let res = (^nix-update --flake --system $system ...$spec.args $attr | complete)
        if $res.exit_code == 0 {
            ^git add -- nix/
            $succeeded = $succeeded + 1
        } else {
            ^git checkout -- nix/
            let err_msg = $res.stderr | str trim
            print -e $"Warning: failed to update ($spec.name):\n($err_msg)"
            $failures = ($failures | append {name: $spec.name, error: $err_msg})
        }
    }

    ^git reset --quiet

    if $succeeded > 0 {
        ^nix fmt
        ^nix run .#update-readme
    }

    if ($failures | is-not-empty) {
        let items = (
            $failures
            | each {|f|
                [
                    $"<details><summary><code>($f.name)</code> update failed</summary>"
                    ""
                    "```text"
                    $f.error
                    "```"
                    ""
                    "</details>"
                ]
                | str join "\n"
            }
        )
        let summary = (
            [
                "### ⚠️ Failed Custom Package Updates"
                ""
                ...$items
                ""
            ]
            | str join "\n"
        )
        append-step-summary $summary

        if $succeeded == 0 {
            error make {msg: $"All ($failures | length) custom package update\(s\) failed"}
        }
    }
}
