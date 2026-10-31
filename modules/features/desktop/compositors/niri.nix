{
  baseVars,
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
      settings.session.default = "niri";
    };
  };
}
