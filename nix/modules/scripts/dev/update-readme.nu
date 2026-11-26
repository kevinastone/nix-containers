def render-row [c: record]: nothing -> string {
    let link = $c.docPath
    let platforms = $c.platforms | each { $"`($in)`" } | str join ", "
    let recipe = $"[recipe]\(($c.recipePath)\)"
    let desc = if ($c.description | is-not-empty) {
        $"($c.description) \(($recipe)\)"
    } else {
        $recipe
    }
    let image = $"ghcr.io/kevinastone/nix-containers/($c.name)"
    $"| [`($c.name)`]\(($link)\) | [`($image)`]\(https://($image)\) | ($platforms) | ($desc) |"
}

def render-catalog [catalog: list<record>]: nothing -> string {
    [
        "<!-- BEGIN:CONTAINER_CATALOG -->"
        "| Container | Image | Platforms | Description |"
        "| --- | --- | --- | --- |"
        ...($catalog | each { render-row $in })
        "<!-- END:CONTAINER_CATALOG -->"
    ]
    | str join "\n"
}

# Update (or --check) the container catalog table between markers in README.md.
def main [
    readme: path = "./README.md" # Path to README.md
    --catalog-json: path # Path to JSON export of flake.lib.catalog
    --check # Fail if README.md is out of date instead of writing
] {
    let readme = $readme | path expand
    if not ($readme | path exists) {
        error make {msg: $"README not found: ($readme)"}
    }
    if $catalog_json == null {
        error make {msg: "--catalog-json is required"}
    }

    let content = (open --raw $readme)
    let start_marker = "<!-- BEGIN:CONTAINER_CATALOG -->"
    let end_marker = "<!-- END:CONTAINER_CATALOG -->"

    if not (($content | str contains $start_marker) and ($content | str contains $end_marker)) {
        error make {msg: $"Missing ($start_marker) / ($end_marker) markers in ($readme)"}
    }

    let catalog = (open $catalog_json)
    let rendered = (render-catalog $catalog)
    let before = $content | split row -n 2 $start_marker | first
    let after = $content | split row -n 2 $end_marker | last
    let expected = $"($before)($rendered)($after)"

    if $check {
        if $content != $expected {
            error make {
                msg: "README.md container catalog is out of date. Run: nix run .#update-readme"
            }
        }
        print "README.md container catalog is up to date."
    } else {
        $expected | save --force $readme
        print $"Updated container catalog in ($readme)"
    }
}
