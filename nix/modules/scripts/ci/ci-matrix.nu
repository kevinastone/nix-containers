def is-fork-pr []: nothing -> bool {
    let event = $env.GITHUB_EVENT_NAME? | default ""
    let head_repo = $env.GITHUB_HEAD_REPO? | default ""
    let base_repo = $env.GITHUB_REPOSITORY? | default ""
    ($event == "pull_request") and ($head_repo != "") and ($head_repo != $base_repo)
}

def remote-annotations [ref: string]: nothing -> record {
    with-retry 3 $"regctl manifest get ($ref)" {
        let res = (^regctl manifest get $ref --format raw-body | complete)
        if $res.exit_code == 0 {
            return ($res.stdout | from json | get -o annotations | default {})
        }

        let err = $res.stderr | str lowercase
        let is_not_found = (
            ($err | str contains "manifest_unknown")
            or ($err | str contains "name_unknown")
            or ($err | str contains "not found")
            or ($err | str contains "status 404")
        )
        if $is_not_found {
            return {}
        }

        let is_auth_denied = (
            ($err | str contains "unauthorized")
            or ($err | str contains "denied")
            or ($err | str contains "status 401")
            or ($err | str contains "status 403")
        )
        if (is-fork-pr) and $is_auth_denied {
            print -e $"Warning: anonymous read denied for ($ref) on fork PR; treating as changed"
            return {}
        }

        error make {msg: ($res.stderr | str trim)}
    }
}

# Filter the Nix CI container list to only containers whose Nix drvPaths changed vs the registry.
def main [
    repo: string # Base registry repository prefix (e.g. ghcr.io/owner/repo)
    ci_json: string = "" # Optional JSON output of `nix eval --json .#lib.ci` (evaluated automatically when omitted)
    --tag: string = "main" # Registry tag to inspect for dev.nix-containers.drv.<arch>
    --github-output: path # Optional $GITHUB_OUTPUT file path
    --force # Include all containers regardless of registry state
] {
    let repo = $repo | str lowercase
    let raw_ci = if $ci_json != "" {
        $ci_json
    } else {
        ^nix eval --json .#lib.ci
    }
    let entries = $raw_ci | from json

    let changed = (
        $entries
        | par-each --threads 8 {|entry|
            let unchanged = if $force {
                false
            } else {
                let remote = (remote-annotations $"($repo)/($entry.container):($tag)")
                $entry.drvs
                | transpose arch drv
                | all {|it| ($remote | get -o $"dev.nix-containers.drv.($it.arch)") == $it.drv }
            }
            if $unchanged {
                print -e $"Skipping ($entry.container) \(unchanged\)"
                null
            } else {
                print -e $"Building ($entry.container)"
                $entry
            }
        }
        | compact
    )

    let result = {
        matrix: $changed
        has_changes: ($changed | is-not-empty)
    }

    if $github_output != null {
        append-github-output $github_output {
            matrix: ($result.matrix | to json -r)
            has_changes: $result.has_changes
        }
    } else {
        $result | to json -r
    }
}
