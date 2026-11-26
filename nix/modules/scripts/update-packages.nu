# Update all locally defined custom packages in the flake via nix-update.
def main [
    ...packages: string # Specific package names to update (defaults to all flake.lib.updatePackages)
] {
    let targets = if ($packages | is-empty) {
        ^nix eval --json .#lib.updatePackages | from json
    } else {
        $packages
    }

    if ($targets | is-empty) {
        print "No custom packages to update."
        return
    }

    let system = (^nix eval --raw --impure --expr "builtins.currentSystem" | str trim)

    # Nix 2.35+ `nix flake metadata` does not materialize the flake store path on disk;
    # force realization so `nix-update --flake` can evaluate it via `nix-instantiate`.
    ^nix eval --raw --impure --expr '(builtins.getFlake ("git+file://" + toString ./.)).outPath' | ignore

    for pkg in $targets {
        print $"Updating ($pkg)..."
        ^nix-update --flake --use-github-releases $"legacyPackages.($system).updatePackages.($pkg)"
    }
}
