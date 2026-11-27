const CATEGORIES = [
    {id: "infrastructure", title: "Infrastructure & Identity"}
    {id: "databases", title: "Databases & Storage"}
    {id: "networking", title: "Networking"}
    {id: "security", title: "Security"}
    {id: "monitoring", title: "Monitoring & Hardware"}
    {id: "media", title: "Media & Downloads"}
    {id: "utilities", title: "Utilities"}
]

const DEFAULT_PLATFORMS = ["linux/amd64", "linux/arm64"]

def fmt-bool [val: bool]: nothing -> string {
    if $val { "✓" } else { "—" }
}

def render-features [c: record]: nothing -> string {
    let explicit = $c | get -o features | default []
    let platform_features = if $c.platforms != $DEFAULT_PLATFORMS and ($c.platforms | is-not-empty) {
        let arches = $c.platforms | each { str replace "linux/" "" } | str join ","
        [$"($arches)-only"]
    } else {
        []
    }
    let all_features = [...$explicit, ...$platform_features] | uniq
    if ($all_features | is-empty) {
        "—"
    } else {
        $all_features | each { $"`($in)`" } | str join " "
    }
}

def render-row [c: record]: nothing -> string {
    let is_variant = ($c | get -o parent) != null
    let prefix = if $is_variant { "↳ " } else { "" }
    let image_url = $"https://ghcr.io/kevinastone/nix-containers/($c.name)"
    let title_link = $"[`($c.name)`]\(($c.docPath)\)"
    let links = (
        [
            $"[📦]\(($image_url) \"GHCR image\"\)"
            $"[❄️]\(($c.recipePath) \"Nix recipe\"\)"
        ]
        | str join " "
    )
    let name_cell = $"($prefix)($title_link) ($links)"
    let non_root = fmt-bool ($c | get -o runAsNonRoot | default true)
    let ro_root = fmt-bool ($c | get -o readOnlyRoot | default true)
    let shell = fmt-bool ($c | get -o enableShell | default false)
    let features = render-features $c
    let desc = $c.description | str trim
    $"| ($name_cell) | ($non_root) | ($ro_root) | ($shell) | ($features) | ($desc) |"
}

def order-entries [entries: list<record>]: nothing -> list<record> {
    let bases = $entries | where { ($in | get -o parent) == null } | sort-by name
    let ordered = (
        $bases
        | each {|b|
            let kids = $entries | where { ($in | get -o parent) == $b.name } | sort-by name
            [$b, ...$kids]
        }
        | flatten
    )
    let placed = $ordered | get name
    let orphans = $entries | where { $in.name not-in $placed } | sort-by name
    [...$ordered, ...$orphans]
}

def render-section [title: string, entries: list<record>]: nothing -> string {
    let ordered = (order-entries $entries)
    [
        $"### ($title)"
        ""
        "| Container | Non-Root | RO Root | Shell | Features | Description |"
        "| :--- | :---: | :---: | :---: | :---: | :--- |"
        ...($ordered | each { render-row $in })
    ]
    | str join "\n"
}

def render-catalog [catalog: list<record>]: nothing -> string {
    let known_ids = $CATEGORIES | get id
    let known_sections = (
        $CATEGORIES
        | each {|cat|
            let matching = $catalog | where category == $cat.id
            if ($matching | is-empty) {
                null
            } else {
                render-section $cat.title $matching
            }
        }
        | compact
    )
    let other = $catalog | where { $in.category not-in $known_ids }
    let all_sections = if ($other | is-empty) {
        $known_sections
    } else {
        $known_sections | append (render-section "Other" $other)
    }

    [
        "<!-- BEGIN:CONTAINER_CATALOG -->"
        ($all_sections | str join "\n\n")
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
