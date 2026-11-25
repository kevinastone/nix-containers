# Run container-structure-test against a loaded container image.
def main [
    runtime: string # Container runtime (docker or podman)
    image: string # Loaded image reference
    --config: path # Path to container-structure-test YAML config
] {
    if $config == null {
        error make {msg: "--config is required"}
    }
    let cfg = $config | path expand
    let extra_env = if $runtime == "podman" and ("DOCKER_HOST" not-in $env) {
        let sock = (
            ^podman info --format json
            | from json
            | get -o host.remoteSocket.path
            | default ""
        )
        if ($sock | is-not-empty) {
            {DOCKER_HOST: $"unix://($sock)"}
        } else {
            {}
        }
    } else {
        {}
    }
    with-env $extra_env {
        ^container-structure-test test --image $image --config $cfg
    }
}
