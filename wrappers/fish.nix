{
  inputs,
  pkgs,
  wlib,
  lib,
  system,
  ...
}:
let
  commandNotFoundWrapper = pkgs.writeScript "command-not-found" ''
    #!${pkgs.bash}/bin/bash
    source ${inputs.nix-index-database.packages.${system}.nix-index-with-small-db}/etc/profile.d/command-not-found.sh
    command_not_found_handle "$@"
  '';

  fishConf = pkgs.writeText "experiment-config.fish" ''
    alias lgit="lazygit"
    ${lib.getExe pkgs.zoxide} init fish | source
    ${lib.getExe pkgs.direnv} hook fish | source

    function __fish_command_not_found_handler --on-event fish_command_not_found
      ${commandNotFoundWrapper} $argv
    end
  '';
in
{
  imports = [ wlib.modules.default ];

  config = {
    package = pkgs.fish;

    extraPackages = [
      pkgs.direnv
      pkgs.lazygit
      pkgs.lorri
      pkgs.zoxide
    ];

    flags = {
      "-C" = "source ${fishConf}";
    };
  };
}
