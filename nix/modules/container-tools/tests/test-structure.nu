# Run container-structure-test against a loaded container image.
def main [
    runtime: string # Container runtime (docker or podman)
    image: string # Loaded image reference
    ...configs: path # Path(s) to container-structure-test YAML config(s)
] {
    if ($configs | is-empty) {
        error make {msg: "At least one structure-test config path is required"}
    }
    let cfg_flags = $configs | each {|c| [--config ($c | path expand)] } | flatten
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
        ^container-structure-test test --image $image ...$cfg_flags
    }
}
