{ lib, config, ... }:
with lib;
let
  program = "wpaperd";
  program-module = config.modules.${program};
in
{
  options.modules.${program} = {
    enable = mkEnableOption "enables ${program} config";
  };

  config = mkIf program-module.enable {
    services.${program} = {
      enable = true;
      settings = {
        default = {
          path = "~/Pictures/Wallpapers/";
          duration = "30m";
          # apply-shadow = true;
        };
      };
    };
  };
}
