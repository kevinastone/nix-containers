const COMMENT_MARKER = "<!-- nix-containers-changelog -->"

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

def generate-report [
    before_dir: string
    after_dir: string
    title: string
    run_url: string
]: nothing -> record<markdown: string, has_changes: bool> {
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
            if $run_url != "" { [$"\n> **Workflow run**: ($run_url)"] } else { [] }
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

    {
        markdown: $"($body)\n"
        has_changes: $has_changes
    }
}

def sync-pr-comment [pr_number: string, markdown: string, has_changes: bool] {
    let repo = $env.GITHUB_REPOSITORY? | default ""
    if $pr_number == "" or $repo == "" {
        return
    }

    let list_res = (
        ^gh api $"repos/($repo)/issues/($pr_number)/comments?per_page=100"
        | complete
    )
    if $list_res.exit_code != 0 {
        print -e $"Skipping PR comment sync \(unable to list comments: ($list_res.stderr | str trim)\)"
        return
    }

    let comments = $list_res.stdout | from json
    let existing = (
        $comments
        | where { ($in.body? | default "") | str contains $COMMENT_MARKER }
    )
    let body = $"($COMMENT_MARKER)\n($markdown)"

    if ($existing | is-not-empty) {
        let comment_id = $existing.0.id
        let res = (
            ^gh api --method PATCH $"repos/($repo)/issues/comments/($comment_id)" -f $"body=($body)"
            | complete
        )
        if $res.exit_code != 0 {
            print -e $"Skipping PR comment update \(($res.stderr | str trim)\)"
        } else {
            print $"Updated PR #($pr_number) changelog comment."
        }
    } else if $has_changes {
        let res = (
            ^gh api --method POST $"repos/($repo)/issues/($pr_number)/comments" -f $"body=($body)"
            | complete
        )
        if $res.exit_code != 0 {
            print -e $"Skipping PR comment creation \(($res.stderr | str trim)\)"
        } else {
            print $"Posted PR #($pr_number) changelog comment."
        }
    } else {
        print $"No container derivations changed; skipping PR #($pr_number) comment."
    }
}

# Compare container derivations across two flake trees and render a PR changelog with `nvd`.
def main [
    before_dir: string = "" # Optional path to baseline flake checkout (uses --base-ref worktree when omitted)
    after_dir: path = "." # Path to updated flake checkout
    --base-ref: string = "origin/main" # Git ref to compare against when before_dir is omitted
    --body-file: path # Optional file path to save the rendered markdown PR body
    --title: string = "## 📦 Container Closure Changelog" # Header line for the rendered markdown report
    --run-url: string = "" # Optional GitHub Actions workflow run URL to include
    --pr-number: string = "" # Optional pull request number for posting/updating an idempotent sticky comment
] {
    let report = if $before_dir != "" {
        (generate-report
            $before_dir
            ($after_dir | into string)
            $title
            $run_url
        )
    } else {
        let resolved = (resolve-git-ref $base_ref)
        if $resolved == "" {
            error make {msg: $"Unable to resolve baseline git ref '($base_ref)'"}
        }
        let base_sha = (^git rev-parse $resolved | str trim)
        with-git-worktree $base_sha {|wt_dir|
            generate-report $wt_dir ($after_dir | into string) $title $run_url
        }
    }

    if $body_file != null {
        $report.markdown | save --force $body_file
    } else {
        print $report.markdown
    }

    append-step-summary $report.markdown
    sync-pr-comment $pr_number $report.markdown $report.has_changes
}
