{ lib, dockerTools }:
let
  mkUsersNss =
    users:
    dockerTools.fakeNss.override {
      extraPasswdLines = map (
        u:
        "${u.name}:x:${toString u.uid}:${toString u.gid}:Non-root user:${
          if u.home != null then u.home else "/var/empty"
        }:/sbin/nologin"
      ) users;
      extraGroupLines = lib.unique (map (u: "${u.name}:x:${toString u.gid}:") users);
    };

  mkRootfs =
    {
      runAsNonRoot,
      user,
      extraUsers,
      dirs,
      extraCommands,
      fakeRootCommands,
    }:
    let
      allUsers = lib.optional runAsNonRoot user ++ builtins.attrValues extraUsers;

      userHomeDirs = builtins.listToAttrs (
        map (u: {
          name = u.home;
          value = {
            mode = "0755";
            inherit (u) uid gid;
          };
        }) (builtins.filter (u: u.home != null) allUsers)
      );

      defaultDirs = {
        "/tmp" = {
          mode = "1777";
          uid = 0;
          gid = 0;
        };
      }
      // userHomeDirs;

      resolvedDirs = lib.mapAttrs (
        path: spec:
        let
          clean = lib.removeSuffix "/" path;
        in
        assert lib.assertMsg (
          lib.hasPrefix "/" clean && clean != ""
        ) "containerTools: `dirs` key '${path}' must be a non-root absolute path";
        {
          relPath = ".${clean}";
          inherit (spec) mode uid gid;
        }
      ) (defaultDirs // dirs);

      dirList = builtins.attrValues resolvedDirs;

      mkdirCommands = lib.optionalString (dirList != [ ]) (
        "mkdir -p " + lib.escapeShellArgs (map (d: d.relPath) dirList)
      );

      chmodCommands = lib.concatMapStringsSep "\n" (
        d: "chmod ${lib.escapeShellArg d.mode} ${lib.escapeShellArg d.relPath}"
      ) dirList;

      chownCommands = lib.concatMapStringsSep "\n" (
        d: "chown ${toString d.uid}:${toString d.gid} ${lib.escapeShellArg d.relPath}"
      ) dirList;
    in
    {
      nss = lib.optional (allUsers != [ ]) (mkUsersNss allUsers);
      extraCommands = lib.concatStringsSep "\n" (
        lib.filter (s: s != "") [
          mkdirCommands
          extraCommands
        ]
      );
      fakeRootCommands = lib.concatStringsSep "\n" (
        lib.filter (s: s != "") [
          mkdirCommands
          chmodCommands
          chownCommands
          fakeRootCommands
        ]
      );
    };

  mkRootfsTest =
    {
      runAsNonRoot,
      user,
      dirs,
      imageUser,
    }:
    let
      checkHome = runAsNonRoot && user.home != null && !(dirs ? ${user.home});
    in
    {
      _name = "rootfs";
      fileExistenceTests =
        lib.optional checkHome {
          name = "${user.home} exists";
          path = user.home;
          shouldExist = true;
          inherit (user) uid gid;
          permissions = "drwxr-xr-x";
        }
        ++ [
          {
            name = "/tmp exists";
            path = "/tmp";
            shouldExist = true;
          }
        ];
    }
    // lib.optionalAttrs runAsNonRoot {
      metadataTest.user = imageUser;
    };
in
{
  inherit mkRootfs mkRootfsTest;
}
