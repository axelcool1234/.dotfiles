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
      shellWrapperName = "yy"; # TODO: This should be removed eventually when I update `home.stateVersion` in `flake.nix`
    };
    xdg.configFile.${program}.source = ./.;
  };
}
