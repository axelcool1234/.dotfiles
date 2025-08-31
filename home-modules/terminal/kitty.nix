{
  inputs,
  pkgs,
  lib,
  config,
  ...
}:
{
  options = {
    kitty.enable = lib.mkEnableOption "enables kitty config";
  };
  config = lib.mkIf config.kitty.enable {
    xdg.configFile.kitty.source = ./kitty;
    programs.kitty.enable = true;
  };
}
