# Verify required OCI image labels on a loaded container image.
def main [
    runtime: string # Container runtime (docker or podman)
    image: string # Loaded image reference
] {
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
