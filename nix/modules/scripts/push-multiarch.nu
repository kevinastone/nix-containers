def parse-spec [spec: string]: nothing -> record<platform: string, tar: string> {
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
    {platform: $parts.0, tar: $tar}
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

# Import Nix-built OCI archives, assemble a local multi-arch OCI index, and push it to all tags.
def main [
    repo: string # Target registry repository (e.g. ghcr.io/owner/repo/image)
    ...images: string # One or more <platform>=<image-tar> specs
    --tags: string # Newline-separated tags to publish (defaults to $env.TAGS)
    --extra-tags-json: string # Optional JSON list of extra tag names (defaults to $env.EXTRA_TAGS_JSON)
    --source-url: string # OCI org.opencontainers.image.source annotation (defaults to $env.SOURCE_URL)
    --revision: string # OCI org.opencontainers.image.revision annotation (defaults to $env.REVISION)
    --drvs-json: string # JSON map of <arch> -> Nix drvPath (defaults to $env.DRVS_JSON)
    --github-output: path # Optional $GITHUB_OUTPUT file path (writes repo and digest)
] {
    if ($images | is-empty) {
        error make {msg: "At least one <platform>=<image-tar> argument is required"}
    }

    let repo = $repo | str lowercase
    let raw_extra_tags = $extra_tags_json | default ($env.EXTRA_TAGS_JSON? | default "")
    let extra_tag_refs = if $raw_extra_tags == "" {
        []
    } else {
        $raw_extra_tags | from json | each { $"($repo):($in)" }
    }

    let resolved_tags = (
        $tags
        | default ($env.TAGS? | default "")
        | lines
        | each { str trim }
        | where { $in != "" }
        | append $extra_tag_refs
        | uniq
    )
    if ($resolved_tags | is-empty) {
        error make {msg: "No tags provided (pass --tags or set TAGS)"}
    }

    let source = $source_url | default ($env.SOURCE_URL? | default "")
    let rev = $revision | default ($env.REVISION? | default "")
    let raw_drvs = $drvs_json | default ($env.DRVS_JSON? | default "")
    let drvs = if $raw_drvs == "" {
        {}
    } else {
        $raw_drvs | from json
    }
    let specs = $images | each { parse-spec $in }

    let tmp_dir = (mktemp -d)
    try {
        let oci_dir = $tmp_dir | path join "oci"
        let refs = (
            $specs
            | enumerate
            | each {|it|
                let local_ref = $"ocidir://($oci_dir):arch-($it.index)"
                print $"Importing ($it.item.platform) archive..."
                ^regctl image import $local_ref $it.item.tar
                [--ref $local_ref --platform $it.item.platform]
            }
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

        for tag in $resolved_tags {
            print $"Pushing multi-arch OCI index to ($tag)..."
            ^regctl image copy $index_ref $tag
        }

        print $"Published OCI index digest: ($repo)@($index_digest)"

        if $github_output != null {
            [
                $"repo=($repo)"
                $"digest=($index_digest)"
            ]
            | str join "\n"
            | $"($in)\n"
            | save --append $github_output
        }
    } finally {
        rm -rf $tmp_dir
    }
}
