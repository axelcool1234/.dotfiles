{
  inputs,
  lib,
  pkgs,
  selfPkgs,
  system,
  ...
}:
let
  commandNotFoundWrapper = pkgs.writeShellScript "command-not-found" ''
    source ${inputs.nix-index-database.packages.${system}.nix-index-with-small-db}/etc/profile.d/command-not-found.sh
    command_not_found_handle "$@"
  '';
in
{
  imports = [ ./module.nix ];

  config = {
    extraPackages = [
      pkgs.direnv
      selfPkgs.lazygit
      pkgs.lorri
      pkgs.zoxide
    ];

    # The "standalone" wrapper allows helix to take over if
    # a file was selected to be edited from lazygit
    # The >/dev/null suppresses stdout noise when running
    # edit command to open helix from lazgit
    shellAliases = {
      lazygit = "lazygit-standalone >/dev/null";
      lgit = "lazygit-standalone >/dev/null";
    };

    shellInit = ''
      ${lib.getExe pkgs.zoxide} init fish | source
      ${lib.getExe pkgs.direnv} hook fish | source

      function fish_user_key_bindings
        for mode in default insert visual
          bind -M $mode \cz 'fg >/dev/null 2>&1; commandline -f repaint'
          bind -M $mode \cg 'commandline -r lazygit; commandline -f execute'
        end
      end

      function __fish_command_not_found_handler --on-event fish_command_not_found
        ${commandNotFoundWrapper} $argv
      end
    '';
  };
}
