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

    shellAliases.lgit = "lazygit";

    shellInit = ''
      ${lib.getExe pkgs.zoxide} init fish | source
      ${lib.getExe pkgs.direnv} hook fish | source

      function __fish_command_not_found_handler --on-event fish_command_not_found
        ${commandNotFoundWrapper} $argv
      end
    '';
  };
}
