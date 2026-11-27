def render-default-nix [name: string, pkg: string, category: string]: nothing -> string {
    let name_line = if $pkg == $name { "" } else { $"  name = \"($name)\";\n" }
    [
        "{"
        "  containerTools,"
        $"  ($pkg),"
        "}:"
        $"containerTools.buildLayeredImage {\n($name_line)  package = ($pkg);"
        $"  category = \"($category)\";"
        "  structureTest = ./structure-test.yaml;"
        "}"
        ""
    ]
    | str join "\n"
}

def render-structure-test [name: string]: nothing -> string {
    [
        "# yaml-language-server: $schema=https://json.schemastore.org/container-structure-test.json"
        'schemaVersion: "2.0.0"'
        ""
        "commandTests:"
        $'  - name: "($name) version"'
        $'    command: "($name)"'
        '    args: ["--version"]'
        ""
    ]
    | str join "\n"
}

def render-readme [name: string]: nothing -> string {
    [
        $"# `($name)`"
        ""
        $"- **Image**: `ghcr.io/kevinastone/nix-containers/($name)`"
        "- **Recipe**: [default.nix](default.nix)"
        "- **Tests**: [structure-test.yaml](structure-test.yaml)" ""
    ]
    | str join "\n"
}

# Scaffold a new container directory under nix/containers/<name>/.
def main [
    name: string # Container directory and image name (e.g. redis)
    --package (-p): string # Nixpkgs package attribute name (defaults to <name>)
    --category (-c): string = "utilities" # Catalog category (infrastructure, databases, networking, security, monitoring, media, utilities)
    --containers-dir: path = "./nix/containers" # Base containers directory
] {
    if $name !~ '^[a-z0-9][a-z0-9._-]*$' {
        error make {
            msg: $"Invalid container name '($name)' \(must match ^[a-z0-9][a-z0-9._-]*$\)"
        }
    }

    let pkg = $package | default $name
    if $pkg !~ '^[A-Za-z_][A-Za-z0-9_-]*$' {
        error make {msg: $"Invalid Nix package identifier '($pkg)'"}
    }

    let target_dir = $containers_dir | path expand | path join $name
    if ($target_dir | path exists) {
        error make {msg: $"Container directory already exists: ($target_dir)"}
    }

    mkdir $target_dir
    render-default-nix $name $pkg $category | save ($target_dir | path join "default.nix")
    render-structure-test $name | save ($target_dir | path join "structure-test.yaml")
    render-readme $name | save ($target_dir | path join "README.md")

    print $"Scaffolded nix/containers/($name)/ \(default.nix, structure-test.yaml, README.md\)"
}
