{ pkgs }:
{ config, lib, ... }:
let
  inherit (lib) mkOption types;

  cfg = config.dinit;

  processTypes = [
    "process"
    "bgprocess"
    "scripted"
  ];

  restartType = types.enum [
    true
    false
    "on-failure"
  ];

  formatRestart =
    v:
    if v == true then
      "true"
    else if v == false then
      "false"
    else
      v;

  defaultWorkingDir = if config.config.WorkingDir != null then config.config.WorkingDir else "/";

  serviceSubmodule = types.submodule {
    options = {
      type = mkOption {
        type = types.enum [
          "process"
          "bgprocess"
          "scripted"
          "internal"
          "triggered"
        ];
        default = "process";
        description = "Dinit service type.";
      };
      command = mkOption {
        type = types.nullOr types.nonEmptyStr;
        default = null;
        description = "Command (and arguments) executed to start the service.";
      };
      stopCommand = mkOption {
        type = types.nullOr types.nonEmptyStr;
        default = null;
        description = "Command (and arguments) executed to stop the service.";
      };
      pidFile = mkOption {
        type = types.nullOr types.nonEmptyStr;
        default = null;
        description = "PID file path for bgprocess services.";
      };
      workingDir = mkOption {
        type = types.nullOr types.nonEmptyStr;
        default = defaultWorkingDir;
        description = "Working directory for service process execution.";
      };
      runAs = mkOption {
        type = types.nullOr types.nonEmptyStr;
        default = null;
        description = "Username or numeric UID to run the service process as.";
      };
      restart = mkOption {
        type = restartType;
        default = false;
        description = "Whether dinit should automatically restart the service (true, false, or \"on-failure\").";
      };
      smoothRecovery = mkOption {
        type = types.bool;
        default = false;
        description = "Restart crashed process/bgprocess services without stopping dependents.";
      };
      termSignal = mkOption {
        type = types.nullOr types.nonEmptyStr;
        default = null;
        description = "Signal name (without SIG prefix, e.g. \"TERM\" or \"INT\") sent to stop the service.";
      };
      sharesConsole = mkOption {
        type = types.bool;
        default = true;
        description = "Connect service stdout/stderr to container console output (`options: shares-console`).";
      };
      dependsOn = mkOption {
        type = types.listOf types.nonEmptyStr;
        default = [ ];
        description = "Hard service dependencies (`depends-on`).";
      };
      dependsMs = mkOption {
        type = types.listOf types.nonEmptyStr;
        default = [ ];
        description = "Milestone service dependencies (`depends-ms`).";
      };
      waitsFor = mkOption {
        type = types.listOf types.nonEmptyStr;
        default = [ ];
        description = "Soft ordering dependencies (`waits-for`).";
      };
      after = mkOption {
        type = types.listOf types.nonEmptyStr;
        default = [ ];
        description = "Order startup after named services (`after`).";
      };
      before = mkOption {
        type = types.listOf types.nonEmptyStr;
        default = [ ];
        description = "Order startup before named services (`before`).";
      };
      options = mkOption {
        type = types.listOf types.nonEmptyStr;
        default = [ ];
        description = "Additional dinit service options (`options: ...`).";
      };
      extraConfig = mkOption {
        type = types.lines;
        default = "";
        description = "Additional raw lines appended to the dinit service file.";
      };
    };
  };

  renderService =
    svcName: svc:
    let
      isProcess = builtins.elem svc.type processTypes;
      isDaemon = svc.type == "process" || svc.type == "bgprocess";
      effectiveOptions = lib.unique (
        lib.optional (isProcess && svc.sharesConsole) "shares-console" ++ svc.options
      );
      lines = [
        "type = ${svc.type}"
      ]
      ++ lib.optional (isProcess && svc.command != null) "command = ${svc.command}"
      ++ lib.optional (isProcess && svc.stopCommand != null) "stop-command = ${svc.stopCommand}"
      ++ lib.optional (svc.type == "bgprocess" && svc.pidFile != null) "pid-file = ${svc.pidFile}"
      ++ lib.optional (isProcess && svc.workingDir != null) "working-dir = ${svc.workingDir}"
      ++ lib.optional (isProcess && svc.runAs != null) "run-as = ${svc.runAs}"
      ++ [ "restart = ${formatRestart svc.restart}" ]
      ++ lib.optional (isDaemon && svc.smoothRecovery) "smooth-recovery = true"
      ++ lib.optional (isDaemon && svc.termSignal != null) "term-signal = ${svc.termSignal}"
      ++ map (d: "depends-on: ${d}") svc.dependsOn
      ++ map (d: "depends-ms: ${d}") svc.dependsMs
      ++ map (d: "waits-for: ${d}") svc.waitsFor
      ++ map (d: "after: ${d}") svc.after
      ++ map (d: "before: ${d}") svc.before
      ++ map (o: "options: ${o}") effectiveOptions
      ++ lib.optional (svc.extraConfig != "") svc.extraConfig;
    in
    assert lib.assertMsg (
      !isProcess || svc.command != null
    ) "containerTools.mixins.dinit: service '${svcName}' of type '${svc.type}' requires `command`";
    assert lib.assertMsg (
      svc.type != "bgprocess" || svc.pidFile != null
    ) "containerTools.mixins.dinit: bgprocess service '${svcName}' requires `pidFile`";
    lib.concatStringsSep "\n" lines + "\n";

  defaultTargets = builtins.filter (n: n != "boot") (builtins.attrNames cfg.services);

  serviceFiles =
    lib.mapAttrs renderService cfg.services
    // lib.optionalAttrs (!(cfg.services ? boot)) {
      boot =
        lib.concatStringsSep "\n" (
          [
            "type = internal"
            "restart = false"
          ]
          ++ map (t: "depends-on: ${t}") cfg.targets
        )
        + "\n";
    };

  servicesDir =
    assert lib.assertMsg (
      cfg.services != { }
    ) "containerTools.mixins.dinit: `dinit.services` must define at least one service";
    pkgs.runCommand "${config.name}-dinit-services"
      {
        nativeBuildInputs = [ pkgs.dinit ];
      }
      (
        ''
          mkdir -p "$out"
        ''
        + lib.concatStringsSep "\n" (
          lib.mapAttrsToList (
            svcName: svcText: "cp ${pkgs.writeText "dinit-${svcName}" svcText} \"$out/${svcName}\""
          ) serviceFiles
        )
        + ''

          dinit-check --services-dir "$out" boot
        ''
      );

  defaultEntrypoint = [
    "/bin/dinit"
    "--container"
  ]
  ++ lib.optional cfg.quiet "--quiet"
  ++ lib.optionals (cfg.consoleLevel != null) [
    "--console-level"
    cfg.consoleLevel
  ]
  ++ [
    "--services-dir"
    "${servicesDir}"
    "--socket-path"
    cfg.socketPath
  ];
in
{
  options.dinit = {
    services = mkOption {
      type = types.attrsOf serviceSubmodule;
      default = { };
      description = "Declarative dinit service definitions.";
    };
    targets = mkOption {
      type = types.listOf types.nonEmptyStr;
      default = defaultTargets;
      description = "Service names activated by the synthetic `boot` target.";
    };
    socketPath = mkOption {
      type = types.nonEmptyStr;
      default = "/tmp/dinitctl";
      description = "Path to the dinit control socket.";
    };
    quiet = mkOption {
      type = types.bool;
      default = true;
      description = "Suppress dinit service status lines on stdout (`--quiet`).";
    };
    consoleLevel = mkOption {
      type = types.nullOr (
        types.enum [
          "debug"
          "info"
          "warn"
          "error"
          "none"
        ]
      );
      default = "warn";
      description = "Minimum dinit diagnostic log level written to console (`--console-level`).";
    };
  };

  config = {
    contents = lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.dinit ];
    config.Entrypoint = lib.mkDefault defaultEntrypoint;
    structureTest = [
      {
        _name = "${config.name}-dinit";
        metadataTest.entrypoint = config.config.Entrypoint;
        commandTests = [
          {
            name = "dinit version";
            command = "dinit";
            args = [ "--version" ];
            expectedOutput = [ "Dinit version" ];
          }
          {
            name = "dinit-check services";
            command = "dinit-check";
            args = [
              "--services-dir"
              "${servicesDir}"
              "boot"
            ];
            expectedOutput = [ "No problems found\\." ];
          }
        ];
      }
    ];
  };
}
