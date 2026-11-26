def linux-system [arch: string = ""]: nothing -> string {
    let a = if $arch != "" { $arch } else { $nu.os-info.arch }
    match $a {
        "amd64" | "x86_64" => "x86_64-linux"
        "arm64" | "aarch64" => "aarch64-linux"
        _ => $"($a)-linux"
    }
}

def append-github-output [output_path, entries: record] {
    if $output_path == null {
        return
    }
    $entries
    | transpose k v
    | each { $"($in.k)=($in.v)" }
    | str join "\n"
    | $"($in)\n"
    | save --append $output_path
}

def append-step-summary [markdown: string] {
    let summary_path = $env.GITHUB_STEP_SUMMARY? | default ""
    if $summary_path != "" {
        $markdown | save --append $summary_path
    }
}

def with-retry [attempts: int, label: string, action: closure] {
    mut attempt = 1
    mut delay = 1sec
    loop {
        let outcome = (
            try {
                {ok: true, value: (do $action)}
            } catch {|err|
                {ok: false, err: $err}
            }
        )
        if $outcome.ok {
            return $outcome.value
        }
        if $attempt >= $attempts {
            error make {
                msg: $"($label) failed after ($attempts) attempts: ($outcome.err.msg)"
            }
        }
        print -e $"($label) failed \(attempt ($attempt)/($attempts)\); retrying in ($delay)..."
        sleep $delay
        $attempt = $attempt + 1
        $delay = $delay * 2
    }
}

def resolve-git-ref [ref: string]: nothing -> string {
    if ($ref | str starts-with "origin/") {
        let branch = $ref | str replace "origin/" ""
        let fetched = (^git fetch --no-tags --depth=1 origin $branch | complete)
        if $fetched.exit_code == 0 {
            return "FETCH_HEAD"
        }
    }
    let verified = (^git rev-parse --verify $"($ref)^{commit}" | complete)
    if $verified.exit_code == 0 {
        return ($verified.stdout | str trim)
    }
    ""
}

def with-git-worktree [commit_ref: string, action: closure] {
    let wt_dir = (mktemp -d)
    try {
        ^git worktree add --detach --quiet $wt_dir $commit_ref
        do $action $wt_dir
    } finally {
        ^git worktree remove --force $wt_dir | complete | ignore
        rm -rf $wt_dir
    }
}
