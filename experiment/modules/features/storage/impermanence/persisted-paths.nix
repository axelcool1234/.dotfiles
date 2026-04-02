{ config, lib, ... }:
let
  cfg = config.preferences.impermanence;

  packageHasPersist = pkg:
    builtins.isAttrs pkg
    && pkg ? passthru
    && pkg.passthru ? persist;

  persistEnabled = persist:
    !(persist ? requiresFlatpak)
    || !persist.requiresFlatpak
    || config.services.flatpak.enable;

  packagePersist = map (
    pkg: pkg.passthru.persist
  ) (builtins.filter (
    pkg: packageHasPersist pkg && persistEnabled pkg.passthru.persist
  ) config.environment.systemPackages);

  collectPersist = key:
    lib.unique (
      lib.flatten (
        map (
          persist: persist.${key} or [ ]
        ) packagePersist
      )
    );

  wrapperSystemDirectories = collectPersist "systemDirectories";
  wrapperSystemFiles = collectPersist "systemFiles";
  wrapperHomeDirectories = collectPersist "homeDirectories";
  wrapperHomeFiles = collectPersist "homeFiles";
in
{
  config = lib.mkIf cfg.enable {
    environment.persistence."/persist" = {
      hideMounts = true;

      directories = wrapperSystemDirectories
      ++ cfg.persist.systemDirectories;

      files = wrapperSystemFiles
      ++ cfg.persist.systemFiles;

      users.${cfg.user} = {
        directories = wrapperHomeDirectories
        ++ cfg.persist.homeDirectories;
        files = wrapperHomeFiles ++ cfg.persist.homeFiles;
      };
    };
  };
}
