{
  config,
  lib,
  myLib,
  ...
}:
let
  cfg = config.preferences.impermanence;

  packagePersist = map (
    pkg: pkg.passthru.persist
  ) (builtins.filter (
    pkg: myLib.packageHasPersist pkg
  ) config.environment.systemPackages);

  wrapperSystemDirectories = myLib.collectPersist "systemDirectories" packagePersist;
  wrapperSystemFiles = myLib.collectPersist "systemFiles" packagePersist;
  wrapperHomeDirectories = myLib.collectPersist "homeDirectories" packagePersist;
  wrapperHomeFiles = myLib.collectPersist "homeFiles" packagePersist;
in
{
  config = lib.mkMerge [
    {
      preferences.impermanence.persist.systemDirectories = [
        "/var/log"
        "/var/lib/nixos"
      ];

      preferences.impermanence.persist.systemFiles = [
        "/etc/machine-id"
      ];

      preferences.impermanence.persist.homeDirectories = [
        ".dotfiles"
        { directory = ".ssh"; mode = "0700"; }
        ".cache/nix"
      ];
    }
    (lib.mkIf cfg.enable {
      environment.persistence."/persist" = {
        hideMounts = true;

        directories = wrapperSystemDirectories
        ++ cfg.persist.systemDirectories;

        files = wrapperSystemFiles
        ++ cfg.persist.systemFiles;

        users.${cfg.user} = {
          directories = wrapperHomeDirectories
          ++ cfg.persist.homeDirectories;

          files = wrapperHomeFiles
          ++ cfg.persist.homeFiles;
        };
      };
    })
  ];
}
