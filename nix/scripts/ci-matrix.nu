def remote-annotations [ref: string]: nothing -> record {
    let res = (^regctl manifest get $ref --format raw-body | complete)
    if $res.exit_code != 0 {
        return {}
    }
    try {
        $res.stdout | from json | get -o annotations | default {}
    } catch {
        {}
    }
}

# Filter the Nix CI build/push matrices to only containers whose Nix drvPaths changed vs the registry.
def main [
    repo: string # Base registry repository prefix (e.g. ghcr.io/owner/repo)
    ci_json: string # JSON output of `nix eval --json .#lib.ci`
    --tag: string = "main" # Registry tag to inspect for dev.nix-containers.drv.<arch>
    --github-output: path # Optional $GITHUB_OUTPUT file path
    --force # Include all containers regardless of registry state
] {
    let repo = $repo | str lowercase
    let ci = $ci_json | from json

    let push = (
        $ci.push
        | par-each {|entry|
            let unchanged = if $force {
                false
            } else {
                let remote = remote-annotations $"($repo)/($entry.container):($tag)"
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

    let changed = $push | get container
    let result = {
        build: ($ci.build | where container in $changed)
        push: $push
        has_changes: ($push | is-not-empty)
    }

    if $github_output != null {
        [
            $"build_matrix=($result.build | to json -r)"
            $"push_matrix=($result.push | to json -r)"
            $"has_changes=($result.has_changes)"
        ]
        | str join "\n"
        | $"($in)\n"
        | save --append $github_output
    } else {
        $result | to json -r
    }
}
