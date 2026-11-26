def build-closure [flake_ref: string, container: string]: nothing -> string {
    ^nix build $"($flake_ref)#($container).closure" --no-link --print-out-paths | str trim
}

def render-container-diff [
    before_flake: string
    after_flake: string
    before
    after: record
]: nothing -> string {
    let name = $after.container
    if $before == null {
        return $"### `($name)` \(new container: `($after.version)`\)"
    }

    let old_closure = (build-closure $before_flake $name)
    let new_closure = (build-closure $after_flake $name)
    let diff = (^nvd --color never diff $old_closure $new_closure | str trim)

    [
        "<details>"
        $"<summary><code>($name)</code> runtime closure diff \(<code>nvd</code>\)</summary>"
        ""
        "```text"
        $diff
        "```"
        ""
        "</details>"
    ]
    | str join "\n"
}

# Compare container derivations across two flake trees and render a PR changelog with `nvd`.
def main [
    before_dir: path # Path to baseline flake checkout (e.g. main worktree)
    after_dir: path = "." # Path to updated flake checkout
    --body-file: path # Optional file path to save the rendered markdown PR body
    --title: string = "Automated `flake.lock` update." # Header line for the rendered markdown report
    --run-url: string = "" # Optional GitHub Actions workflow run URL to include
] {
    let before_flake = $"path:($before_dir | path expand)"
    let after_flake = $"path:($after_dir | path expand)"

    let before_ci = (^nix eval --json $"($before_flake)#lib.ci" | from json)
    let after_ci = (^nix eval --json $"($after_flake)#lib.ci" | from json)

    let changed = (
        $after_ci
        | each {|after|
            let match = $before_ci | where container == $after.container
            let before = if ($match | is-empty) { null } else { $match.0 }
            if $before == null or $before.drvs != $after.drvs {
                {before: $before, after: $after}
            } else {
                null
            }
        }
        | compact
    )

    let has_changes = $changed | is-not-empty

    let header = [
        $title
        ...(
            if $run_url != "" { [$"\n> **Update workflow run**: ($run_url)"] } else { [] }
        )
    ]

    let body = if not $has_changes {
        [
            ...$header
            ""
            "No container derivations changed (flake/tooling inputs only)."
        ]
        | str join "\n"
    } else {
        let rows = (
            $changed
            | each {|it|
                let c = $it.after.container
                let ver = if $it.before == null {
                    $"`($it.after.version)` \(new\)"
                } else if $it.before.version != $it.after.version {
                    $"`($it.before.version)` -> `($it.after.version)`"
                } else {
                    $"`($it.after.version)` \(dependencies updated\)"
                }
                $"| `($c)` | ($ver) |"
            }
        )

        let details = (
            $changed
            | each {|it| render-container-diff $before_flake $after_flake $it.before $it.after }
        )

        [
            ...$header
            ""
            "| Container | Version |"
            "| --- | --- |"
            ...$rows
            ""
            ...($details | str join "\n\n" | [$in])
        ]
        | str join "\n"
    }

    let rendered = $"($body)\n"

    if $body_file != null {
        $rendered | save --force $body_file
    } else {
        print $rendered
    }

    let summary_path = $env.GITHUB_STEP_SUMMARY? | default ""
    if $summary_path != "" {
        $rendered | save --append $summary_path
    }
}
