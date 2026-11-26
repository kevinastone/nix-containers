def parse-spec [spec: string]: nothing -> record<arch: string, platform: string, tar: string> {
    let parts = $spec | split row -n 2 "="
    if ($parts | length) != 2 or ($parts.0 | is-empty) or ($parts.1 | is-empty) {
        error make {
            msg: $"Invalid image spec '($spec)' \(expected <platform>=<image-tar>\)"
        }
    }
    let tar = $parts.1 | path expand
    if not ($tar | path exists) {
        error make {msg: $"Image archive not found: ($parts.1)"}
    }
    let arch = $parts.0 | split row "/" | last
    {arch: $arch, platform: $parts.0, tar: $tar}
}

def discover-specs [artifacts_dir: string, images: list<string>]: nothing -> list<record<arch: string, platform: string, tar: string>> {
    if ($images | is-not-empty) {
        return ($images | each { parse-spec $in })
    }
    if $artifacts_dir == "" {
        error make {
            msg: "Provide --artifacts-dir or at least one <platform>=<image-tar> argument"
        }
    }
    let dir = $artifacts_dir | path expand
    let tars = glob $"($dir)/*.tar.gz"
    if ($tars | is-empty) {
        error make {msg: $"No *.tar.gz archives found in ($dir)"}
    }
    $tars
    | sort
    | each {|tar|
        let arch = $tar | path basename | str replace ".tar.gz" ""
        {arch: $arch, platform: $"linux/($arch)", tar: $tar}
    }
}

def oci-labels [image_ref: string]: nothing -> record {
    let entries = (
        ^regctl image config $image_ref --format raw-body
        | from json
        | get -o config.Labels
        | default {}
        | transpose k v
        | where { $in.k | str starts-with "org.opencontainers.image." }
    )
    if ($entries | is-empty) {
        {}
    } else {
        $entries | transpose -r -d
    }
}

def resolve-tag-refs [repo: string, tags_json: string, include_main: bool]: nothing -> list<string> {
    let raw = if $tags_json != "" {
        $tags_json
    } else {
        $env.TAGS_JSON? | default "[]"
    }
    let base_tags = $raw | from json
    let all_tags = (
        $base_tags
        | if $include_main { append "main" } else { $in }
        | where { $in != "" }
        | uniq
    )
    if ($all_tags | is-empty) {
        error make {msg: "No tags resolved (pass --tags-json or --include-main)"}
    }
    $all_tags | each { $"($repo):($in)" }
}

# Assemble a multi-arch OCI index from Nix archives and push it by digest only (before signing/attestation).
def "main stage" [
    repo: string # Target registry repository (e.g. ghcr.io/owner/repo/image)
    ...images: string # Optional <platform>=<image-tar> specs (when --artifacts-dir is omitted)
    --artifacts-dir: string = "" # Directory containing <arch>.tar.gz archives
    --source-url: string # OCI org.opencontainers.image.source annotation (defaults to $env.SOURCE_URL)
    --revision: string # OCI org.opencontainers.image.revision annotation (defaults to $env.REVISION)
    --drvs-json: string # JSON map of <arch> -> Nix drvPath (defaults to $env.DRVS_JSON)
    --github-output: path # Optional $GITHUB_OUTPUT file path
] {
    let repo = $repo | str lowercase
    let source = $source_url | default ($env.SOURCE_URL? | default "")
    let rev = $revision | default ($env.REVISION? | default "")
    let raw_drvs = $drvs_json | default ($env.DRVS_JSON? | default "")
    let drvs = if $raw_drvs == "" {
        {}
    } else {
        $raw_drvs | from json
    }
    let specs = (discover-specs $artifacts_dir $images)

    let tmp_dir = (mktemp -d)
    try {
        let oci_dir = $tmp_dir | path join "oci"
        let imported = (
            $specs
            | enumerate
            | each {|it|
                let local_ref = $"ocidir://($oci_dir):arch-($it.index)"
                print $"Importing ($it.item.platform) archive..."
                ^regctl image import $local_ref $it.item.tar
                let manifest_digest = (^regctl image digest $local_ref | str trim)
                {
                    arch: $it.item.arch
                    platform: $it.item.platform
                    local_ref: $local_ref
                    digest: $manifest_digest
                }
            }
        )

        let refs = (
            $imported
            | each { [--ref $in.local_ref --platform $in.platform] }
            | flatten
        )
        let base_annotations = (oci-labels $"ocidir://($oci_dir):arch-0")
        let drv_annotations = (
            $drvs
            | transpose k v
            | reduce -f {} {|it, acc| $acc | upsert $"dev.nix-containers.drv.($it.k)" $it.v }
        )
        let annotations = (
            $base_annotations
            | merge $drv_annotations
            | if ($source != "") { upsert "org.opencontainers.image.source" $source } else { $in }
            | if ($rev != "") { upsert "org.opencontainers.image.revision" $rev } else { $in }
            | transpose k v
            | each { [--annotation $"($in.k)=($in.v)"] }
            | flatten
        )

        let index_ref = $"ocidir://($oci_dir):index"
        print "Assembling multi-arch OCI index..."
        ^regctl index create $index_ref ...$annotations ...$refs

        let index_digest = (^regctl image digest $index_ref | str trim)
        let digest_ref = $"($repo)@($index_digest)"

        print $"Pushing multi-arch OCI index by digest to ($digest_ref)..."
        with-retry 3 $"push ($digest_ref)" {
            ^regctl image copy $index_ref $digest_ref
        }

        let arch_map = (
            $imported
            | reduce -f {} {|it, acc| $acc | upsert $it.arch $it.digest }
        )

        append-github-output $github_output {
            repo: $repo
            digest: $index_digest
            amd64_digest: ($arch_map | get -o amd64 | default "")
            arm64_digest: ($arch_map | get -o arm64 | default "")
        }
    } finally {
        rm -rf $tmp_dir
    }
}

# Promote a signed and attested multi-arch OCI index digest to mutable tags (:main and semver tags).
def "main promote" [
    repo: string # Target registry repository (e.g. ghcr.io/owner/repo/image)
    digest: string # Multi-arch OCI index digest (sha256:...)
    --tags-json: string = "" # JSON list of tags to publish (defaults to $env.TAGS_JSON)
    --include-main # Also promote the :main branch tag
] {
    let repo = $repo | str lowercase
    let src_ref = $"($repo)@($digest)"
    let tag_refs = (resolve-tag-refs $repo $tags_json $include_main)

    for tag_ref in $tag_refs {
        print $"Promoting ($src_ref) -> ($tag_ref)..."
        with-retry 3 $"promote ($tag_ref)" {
            ^regctl image copy $src_ref $tag_ref
        }
    }
}

# Stage and promote multi-arch OCI manifests (`push-multiarch stage` / `push-multiarch promote`).
def main [] {
    help main
}
