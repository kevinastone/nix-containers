# Verify Kubernetes restricted Pod Security Standard compatibility on a loaded image.
def main [
    runtime: string # Container runtime (docker or podman)
    image: string # Loaded image reference
    --config: path # Optional container-structure-test YAML whose commandTests are run restricted
] {
    let user = (
        ^$runtime inspect $image
        | from json
        | first
        | get -o Config.User
        | default ""
        | str trim
    )
    let uid = try {
        $user | split row ":" | first | into int
    } catch {
        null
    }
    if $uid == null or $uid <= 0 {
        error make {
            msg: $"Restricted PSS check failed: image ($image) must set a numeric non-zero UID in Config.User \(got '($user)'\)"
        }
    }
    print $"Verified numeric non-root UID ($uid) \(User='($user)'\) on ($image)"

    if $config == null {
        return
    }

    let tests = open ($config | path expand) | get -o commandTests | default []
    for test in $tests {
        if (($test | get -o setup | default []) | is-not-empty) {
            print $"Skipping restricted run for '($test.name)' \(uses setup commands\)"
            continue
        }

        let env_flags = (
            $test
            | get -o envVars
            | default []
            | each {|e| [-e $"($e.key)=($e.value)"] }
            | flatten
        )
        let args = $test | get -o args | default []
        let expected_code = $test | get -o exitCode | default 0

        print $"Running restricted PSS test '($test.name)'..."
        let res = (
            ^$runtime run --rm
            --read-only
            --tmpfs /tmp:rw,nosuid,nodev,size=64m
            --cap-drop=ALL
            --security-opt=no-new-privileges
            ...$env_flags
            --entrypoint $test.command
            $image
            ...$args
            | complete
        )
        if $res.exit_code != $expected_code {
            error make {
                msg: $"Restricted PSS test '($test.name)' failed \(exit ($res.exit_code), expected ($expected_code)\):\n($res.stdout)\n($res.stderr)"
            }
        }
    }
}
