def detect-runtime []: nothing -> string {
    if (which docker | is-not-empty) {
        "docker"
    } else if (which podman | is-not-empty) {
        "podman"
    } else {
        error make {msg: "Neither docker nor podman found on PATH"}
    }
}

def load-image [runtime: string, archive: path]: nothing -> string {
    let out = (^$runtime load -i $archive | str trim)
    print $out
    let match = $out | parse --regex 'Loaded image(?:\(s\)| ID)?:\s*(?<ref>\S+)'
    if ($match | is-empty) {
        error make {msg: $"Could not parse loaded image ref from: ($out)"}
    }
    $match.0.ref
}

# Load a Nix-built OCI archive once, run all configured container tests, and clean up.
def main [
    archive: path = "./result" # Path to the built OCI tarball
    --tests-json: path # Path to JSON list of {name, bin} test entries
    --runtime: string # Container runtime (defaults to docker, then podman)
    --only: string # Run only the named test
] {
    let archive = $archive | path expand
    if not ($archive | path exists) {
        error make {msg: $"Image archive not found: ($archive)"}
    }
    if $tests_json == null {
        error make {msg: "--tests-json is required"}
    }

    let all_tests = open $tests_json
    let tests = if $only != null {
        $all_tests | where name == $only
    } else {
        $all_tests
    }
    if ($tests | is-empty) {
        if $only != null {
            let available = $all_tests | get name | str join ", "
            error make {msg: $"Unknown test '($only)' \(available: ($available)\)"}
        }
        print "No tests configured; skipping."
        return
    }

    let rt = $runtime | default (detect-runtime)
    let image = (load-image $rt $archive)

    try {
        for test in $tests {
            print $"Running test '($test.name)' against ($image)..."
            ^$test.bin $rt $image
        }
    } finally {
        ^$rt rmi $image | complete | ignore
    }
}
