{ pkgs, lib, config, ... }:
with lib;
let
  program = "thunar";
  program-module = config.modules.${program};
in
{
  options.modules.${program} = {
    enable = mkEnableOption "enables ${program} config";
  };

  config = mkIf program-module.enable {
    home.packages = [ pkgs.thunar ];
    xdg.configFile.Thunar.source = ./assets/Thunar;
    xdg.configFile.xfce4.source = ./assets/xfce4;
  };
}
