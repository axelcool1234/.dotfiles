{ lib, config, ... }:
with lib;
let
  program = "fd";
  program-module = config.modules.${program};
in
{
  options.modules.${program} = {
    enable = mkEnableOption "enables ${program} config";
  };
  config = mkIf program-module.enable {
    programs.${program} = {
      enable = true;
      hidden = true;
    };
  };
}
