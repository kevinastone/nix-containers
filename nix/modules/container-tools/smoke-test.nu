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
    let match = $out | parse --regex 'Loaded image:\s*(?<ref>\S+)'
    if ($match | is-empty) {
        error make {msg: $"Could not parse loaded image ref from: ($out)"}
    }
    $match.0.ref
}

def verify-oci-labels [runtime: string, image: string] {
    let labels = (
        ^$runtime inspect $image
        | from json
        | first
        | get -o Config.Labels
        | default {}
    )
    for key in [
        "org.opencontainers.image.title"
        "org.opencontainers.image.version"
        "org.opencontainers.image.source"
    ] {
        let val = $labels | get -o $key | default ""
        if ($val | is-empty) {
            error make {msg: $"Missing required OCI label '($key)' on ($image)"}
        }
    }
    print $"Verified OCI labels on ($image)"
}

# Load a Nix-built OCI archive, verify OCI labels, and run container-structure-test if --config is given.
def main [
    archive: path = "./result" # Path to the built OCI tarball
    --config: path # Optional container-structure-test YAML config
    --runtime: string # Container runtime (defaults to docker, then podman)
] {
    let archive = $archive | path expand
    if not ($archive | path exists) {
        error make {msg: $"Image archive not found: ($archive)"}
    }

    let rt = $runtime | default (detect-runtime)
    let image = (load-image $rt $archive)

    try {
        verify-oci-labels $rt $image

        if $config != null {
            let cfg = $config | path expand
            print $"Running container-structure-test with ($cfg) against ($image)..."
            ^container-structure-test test --image $image --config $cfg
        }
    } finally {
        ^$rt rmi $image | complete | ignore
    }
}
