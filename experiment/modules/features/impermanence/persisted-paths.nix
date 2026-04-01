{ config, lib, selfPkgs, ... }:
let
  cfg = config.preferences.impermanence;

  hasPackage = package: lib.elem package config.environment.systemPackages;

  usesCode = hasPackage selfPkgs.code;
  usesGlideBrowser = hasPackage selfPkgs.browser;
  usesSpotify = config.services.flatpak.enable && hasPackage selfPkgs.spicetify;
  usesKeyrings = config.networking.networkmanager.enable;
in
{
  config = lib.mkIf cfg.enable {
    environment.persistence.${cfg.persistenceRoot} = {
      hideMounts = true;

      directories = [
        "/var/log"
        "/var/lib/nixos"
      ]
      ++ lib.optionals config.networking.networkmanager.enable [
        "/etc/NetworkManager/system-connections"
      ]
      ++ lib.optionals config.hardware.bluetooth.enable [
        "/var/lib/bluetooth"
      ]
      ++ lib.optionals config.services.openssh.enable [
        "/etc/ssh"
      ]
      ++ cfg.persist.systemDirectories;

      files = [
        "/etc/machine-id"
      ] ++ cfg.persist.systemFiles;

      users.${cfg.user} = {
        directories = [
          ".dotfiles"
          { directory = ".ssh"; mode = "0700"; }
        ]
        ++ lib.optionals usesCode [
          ".code"
        ]
        ++ lib.optionals usesGlideBrowser [
          ".local/state/glide-browser/profile"
        ]
        ++ lib.optionals usesSpotify [
          ".local/share/flatpak"
          ".config/spicetify"
          ".var/app/com.spotify.Client"
        ]
        ++ lib.optionals usesKeyrings [
          { directory = ".local/share/keyrings"; mode = "0700"; }
        ]
        ++ cfg.persist.homeDirectories;
        files = cfg.persist.homeFiles;
      };
    };
  };
}
