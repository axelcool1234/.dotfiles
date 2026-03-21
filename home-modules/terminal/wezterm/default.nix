{
  pkgs,
  lib,
  config,
  ...
}:
with lib;
let
  program = "wezterm";
  program-module = config.modules.${program};
in
{
  options.modules.${program} = {
    enable = mkEnableOption "enables ${program} config";
  };
  config = mkIf program-module.enable {
    programs.${program} = {
      enable = true;
      package = pkgs.wezterm;
    };
    xdg.configFile.${program}.source = ./.;
  };
}
