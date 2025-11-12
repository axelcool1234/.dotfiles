{
  inputs,
  pkgs,
  lib,
  config,
  ...
}:
with lib;
let
  program = "helix";
  program-module = config.modules.${program};
in
{
  options.modules.${program} = {
    enable = mkEnableOption "enables ${program} config";
  };
  config = mkIf program-module.enable {
    programs.${program} = {
      enable = true;
      package = inputs.jump-helix.packages.${pkgs.system}.default;
    };
    xdg.configFile.${program}.source = ./.;
  };
}
