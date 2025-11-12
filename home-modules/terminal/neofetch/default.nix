{ lib, config, ... }:
with lib;
let
  program = "neofetch";
  program-module = config.modules.${program};
in
{
  options.modules.${program} = {
    enable = mkEnableOption "enables ${program} config";
  };
  config = mkIf program-module.enable {
    # programs.${program}.enable = true;
    # TODO: programs.neofetch does not exist, disabled for now :(
    xdg.configFile.${program}.source = ./.;
  };
}
