{
  baseVars,
  hostVars,
  lib,
  pkgs,
  selfPkgs,
  ...
}:
let
  syncNoctaliaConfig = lib.getExe' selfPkgs.noctalia-shell "sync-noctalia-shell-config";
  systemctl = lib.getExe' pkgs.systemd "systemctl";
in
{
  config = lib.mkIf (hostVars.desktopShell == "noctalia-shell") {
    programs.noctalia = {
      enable = true;
      package = selfPkgs.noctalia-shell;
      systemd.enable = true;
    };

    # NixOS does not restart ordinary user services during a system switch.
    # When this wrapper changes, refresh its mutable config and restart the
    # active shell before the compositor reloads configuration that points at
    # the new shell package.
    system.userActivationScripts.activateDesktopShell = {
      text = ''
        if [ "$(${lib.getExe' pkgs.coreutils "id"} -un)" = ${lib.escapeShellArg baseVars.username} ]; then
          state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
          marker_file="$state_dir/noctalia-shell-generation"
          desired_generation=${lib.escapeShellArg "${selfPkgs.noctalia-shell}"}
          current_generation=""

          if [ -r "$marker_file" ]; then
            current_generation="$(${lib.getExe' pkgs.coreutils "cat"} "$marker_file")"
          fi

          if [ "$current_generation" != "$desired_generation" ]; then
            if ${syncNoctaliaConfig} && {
              ! ${systemctl} --user is-active --quiet noctalia.service \
                || ${systemctl} --user restart noctalia.service
            }; then
              ${lib.getExe' pkgs.coreutils "mkdir"} -p "$state_dir"
              ${lib.getExe' pkgs.coreutils "printf"} '%s\n' "$desired_generation" > "$marker_file"
            fi
          fi
        fi
      '';
    };
  };
}
