{ lib, config, ... }:
with lib;
let
  program = "yazi";
  program-module = config.modules.${program};
in
{
  options.modules.${program} = {
    enable = mkEnableOption "enables ${program} config";
  };
  config = mkIf program-module.enable {
    programs.${program} = {
      enable = true;
      enableNushellIntegration = true;
    };
    xdg.configFile.${program}.source = ./.;
  };
}
