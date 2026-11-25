{
  pkgs,
  catalog ? [ ],
  ...
}:
let
  mkNuScript =
    name: file: runtimeInputs: extraArgs:
    pkgs.writers.writeNuBin name (pkgs.lib.optionalAttrs (runtimeInputs != [ ] || extraArgs != [ ]) {
      makeWrapperArgs =
        (pkgs.lib.optionals (runtimeInputs != [ ]) [
          "--prefix"
          "PATH"
          ":"
          (pkgs.lib.makeBinPath runtimeInputs)
        ])
        ++ extraArgs;
    }) (builtins.readFile file);

  catalogFile = pkgs.writeText "catalog.json" (builtins.toJSON catalog);
in
{
  ci-matrix = mkNuScript "ci-matrix" ./ci-matrix.nu [ pkgs.regctl ] [ ];
  push-multiarch = mkNuScript "push-multiarch" ./push-multiarch.nu [ pkgs.regctl ] [ ];
  update-readme =
    mkNuScript "update-readme" ./update-readme.nu
      [ ]
      [
        "--add-flags"
        "--catalog-json"
        "--add-flags"
        "${catalogFile}"
      ];

  dive-archive = pkgs.writeShellApplication {
    name = "dive-archive";
    runtimeInputs = with pkgs; [
      dive
      gzip
    ];
    text = ''
      dive --source docker-archive <(gunzip -c "''${1:-result}")
    '';
  };
}
