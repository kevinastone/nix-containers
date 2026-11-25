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

def push-platform [
    repo: string
    tmp_dir: path
    index: int
    spec: record<platform: string, tar: path>
]: nothing -> list<string> {
    let oci_dir = $tmp_dir | path join $"oci-($index)"

    ^regctl image import $"ocidir://($oci_dir)" $spec.tar
    let digest = (^regctl image digest $"ocidir://($oci_dir)" | str trim)

    print $"Pushing ($spec.platform) digest: ($digest) to ($repo)..."
    ^regctl image copy $"ocidir://($oci_dir)" $"($repo)@($digest)"

    [--ref $"($repo)@($digest)" --platform $spec.platform]
}

# Import Nix-built OCI archives, push single-arch images by digest, and publish a multi-arch OCI index.
def main [
  repo: string # Target registry repository (e.g. ghcr.io/owner/repo/image)
  ...images: string # One or more <platform>=<image-tar> specs
  --tags: string # Newline-separated tags to publish (defaults to $env.TAGS)
  --source-url: string # OCI org.opencontainers.image.source annotation (defaults to $env.SOURCE_URL)
] {
    if ($images | is-empty) {
        error make {msg: "At least one <platform>=<image-tar> argument is required"}
    }

    let repo = $repo | str lowercase
    let resolved_tags = (
    $tags
    | default ($env.TAGS? | default "")
    | lines
    | each { str trim }
    | where { $in != "" }
  )
    if ($resolved_tags | is-empty) {
        error make {msg: "No tags provided (pass --tags or set TAGS)"}
    }

    let resolved_source = $source_url | default ($env.SOURCE_URL? | default "")
    let specs = $images | each {|spec| parse-spec $spec }

    let annotation_args = if $resolved_source != "" {
        [--annotation $"org.opencontainers.image.source=($resolved_source)"]
    } else {
        []
    }

    let tmp_dir = (mktemp -d)
    try {
        let ref_args = (
      $specs
      | enumerate
      | par-each {|item| push-platform $repo $tmp_dir $item.index $item.item }
      | flatten
    )

        for tag in $resolved_tags {
            print $"Creating and pushing OCI index for ($tag)..."
            ^regctl index create $tag ...$annotation_args ...$ref_args
        }
    } finally {
        rm -rf $tmp_dir
    }
}
