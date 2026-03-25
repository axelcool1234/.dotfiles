{
  pkgs,
  wlib,
  lib,
  ...
}:
let
  fishConf = pkgs.writeText "experiment-config.fish" ''
    alias lgit="lazygit"
    ${lib.getExe pkgs.zoxide} init fish | source
    ${lib.getExe pkgs.direnv} hook fish | source
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
