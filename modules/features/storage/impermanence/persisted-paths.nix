{
  config,
  lib,
  myLib,
  ...
}:
let
  cfg = config.preferences.impermanence;
  wrapperSystemDirectories = myLib.collectPersistFromPackages "systemDirectories" config.environment.systemPackages;
  wrapperSystemFiles = myLib.collectPersistFromPackages "systemFiles" config.environment.systemPackages;
  wrapperHomeDirectories = myLib.collectPersistFromPackages "homeDirectories" config.environment.systemPackages;
  wrapperHomeFiles = myLib.collectPersistFromPackages "homeFiles" config.environment.systemPackages;
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
