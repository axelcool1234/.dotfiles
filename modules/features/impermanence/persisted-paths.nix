{
  config,
  lib,
  myLib,
  pkgs,
  ...
}:
let
  cfg = config.preferences.impermanence;
  persistedShadow = "/persist/etc/shadow";
  copyShadow = ''
    copy_shadow() {
      local source="$1"
      local destination="$2"
      local directory
      local temporary

      directory="$(${lib.getExe' pkgs.coreutils "dirname"} "$destination")"
      ${lib.getExe' pkgs.coreutils "install"} -d -m 0755 "$directory"
      temporary="$(${lib.getExe' pkgs.coreutils "mktemp"} --tmpdir="$directory" .shadow.XXXXXX)"
      trap '${lib.getExe' pkgs.coreutils "rm"} -f "$temporary"' EXIT
      ${lib.getExe' pkgs.coreutils "cp"} --archive --reflink=auto "$source" "$temporary"
      ${lib.getExe' pkgs.coreutils "mv"} -f "$temporary" "$destination"
      trap - EXIT
    }
  '';
  syncShadow = pkgs.writeShellScript "persist-shadow" ''
    set -euo pipefail
    ${copyShadow}

    if [[ -s /etc/shadow ]]; then
      copy_shadow /etc/shadow ${lib.escapeShellArg persistedShadow}
    fi
  '';
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

      # passwd atomically replaces /etc/shadow, which is incompatible with
      # persisting the file as a bind mount. Restore it before NixOS updates
      # users, then copy changes back to persistent storage as they occur.
      system.activationScripts = {
        restorePersistedShadow = {
          deps = [ "specialfs" ];
          text = ''
            set -euo pipefail
            ${copyShadow}

            if [[ -s /etc/shadow ]]; then
              copy_shadow /etc/shadow ${lib.escapeShellArg persistedShadow}
            fi
            if [[ -s ${lib.escapeShellArg persistedShadow} ]]; then
              copy_shadow ${lib.escapeShellArg persistedShadow} /etc/shadow
            fi
          '';
        };

        users.deps = [ "restorePersistedShadow" ];
      };

      systemd.paths.persist-shadow = {
        description = "Watch for password database changes";
        wantedBy = [ "multi-user.target" ];
        pathConfig.PathChanged = "/etc/shadow";
      };

      systemd.services.persist-shadow = {
        description = "Copy the password database to persistent storage";
        wantedBy = [ "multi-user.target" ];
        unitConfig.RequiresMountsFor = "/persist";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = syncShadow;
        };
      };
    })
  ];
}
