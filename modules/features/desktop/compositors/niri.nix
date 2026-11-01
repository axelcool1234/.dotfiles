{
  baseVars,
  config,
  hostVars,
  lib,
  pkgs,
  selfPkgs,
  ...
}:
{
  config = lib.mkIf (hostVars.compositor == "niri") {
    programs.niri = {
      enable = true;
      package = selfPkgs.niri;
    };

    # The wrapper-provided user unit knows how to validate and hot-load its new
    # generated config. NixOS only daemon-reloads ordinary user services during
    # a switch, so explicitly invoke that reload for the real desktop user.
    system.userActivationScripts.reloadNiri = {
      text = ''
        if [ "$(${lib.getExe' pkgs.coreutils "id"} -un)" = ${lib.escapeShellArg baseVars.username} ] \
          && ${lib.getExe' pkgs.systemd "systemctl"} --user is-active --quiet niri.service
        then
          ${lib.getExe' pkgs.systemd "systemctl"} --user reload niri.service
        fi
      '';
    };

    services.displayManager.noctalia-greeter = {
      enable = true;
      passwordlessSyncUsers = [ baseVars.username ];
      settings.session.default = "niri";
    };

    # The shell writes its synced palette, wallpaper, and output settings here.
    preferences.impermanence.persist.systemDirectories = lib.mkAfter [
      {
        directory = "/var/lib/noctalia-greeter";
        user = "greeter";
        group = "greeter";
        mode = "0750";
      }
    ];

    # Impermanence creates a new backing directory on the first switch. Seed
    # it with an already-synced live state before systemd activates the bind
    # mount, then leave every later activation untouched.
    system.activationScripts.seedNoctaliaGreeterPersistence = lib.mkIf config.preferences.impermanence.enable {
      deps = [ "createPersistentStorageDirs" ];
      text = ''
        greeter_live=/var/lib/noctalia-greeter
        greeter_persistent=/persist/var/lib/noctalia-greeter

        if [ -f "$greeter_live/sync.toml" ] && [ ! -e "$greeter_persistent/sync.toml" ]; then
          ${lib.getExe' pkgs.coreutils "cp"} --archive "$greeter_live/." "$greeter_persistent/"
        fi
      '';
    };
  };
}
