{
  perSystem =
    { lib, pkgs, ... }:
    {
      _module.args.writeNuApplication =
        {
          name,
          text ? builtins.readFile file,
          file ? null,
          includes ? [ ],
          runtimeInputs ? [ ],
          extraArgs ? [ ],
        }:
        let
          fullText =
            lib.optionalString (includes != [ ]) (
              lib.concatMapStringsSep "\n\n" builtins.readFile includes + "\n\n"
            )
            + text;
        in
        pkgs.writers.writeNuBin name (lib.optionalAttrs (runtimeInputs != [ ] || extraArgs != [ ]) {
          makeWrapperArgs =
            (lib.optionals (runtimeInputs != [ ]) [
              "--prefix"
              "PATH"
              ":"
              (lib.makeBinPath runtimeInputs)
            ])
            ++ extraArgs;
        }) fullText;
    };
}
