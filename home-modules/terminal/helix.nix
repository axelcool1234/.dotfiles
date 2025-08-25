{
  pkgs,
  lib,
  config,
  ...
}:
{
  options = {
    helix.enable = lib.mkEnableOption "enables helix config";
  };
  config = lib.mkIf config.helix.enable {
    xdg.configFile.helix.source = ./helix;
  };
}
