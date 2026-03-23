{ lib, config, ... }:
with lib;
let
  program = ""; # Change this
  program-module = config.modules.${program};
in
{
  options.modules.${program} = {
    enable = mkEnableOption "enables ${program} config";
  };
  config = mkIf program-module.enable {
    programs.${program}.enable = true;
    # xdg.configFile.${program}.source = ./.;
  };
}
