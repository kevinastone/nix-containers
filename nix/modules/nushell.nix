{
  perSystem =
    { lib, pkgs, ... }:
    {
      _module.args.writeNuApplication =
        {
          name,
          text ? builtins.readFile file,
          file ? null,
          runtimeInputs ? [ ],
          extraArgs ? [ ],
        }:
        pkgs.writers.writeNuBin name (lib.optionalAttrs (runtimeInputs != [ ] || extraArgs != [ ]) {
          makeWrapperArgs =
            (lib.optionals (runtimeInputs != [ ]) [
              "--prefix"
              "PATH"
              ":"
              (lib.makeBinPath runtimeInputs)
            ])
            ++ extraArgs;
        }) text;
    };
}
