{
  inputs,
  lib,
  config,
  ...
}:
with lib;
let
  program = "nixcord";
  program-module = config.modules.${program};
in
{
  imports = [
    inputs.nixcord.homeModules.nixcord
  ];
  options.modules.${program} = {
    enable = mkEnableOption "enables ${program} config";
  };
  config = mkIf program-module.enable {
    programs.${program} = {
      enable = true; # Enable Nixcord (It also installs Discord)
      vesktop.enable = true; # Vesktop
      dorion.enable = true; # Dorion
      config = {
        themeLinks = [
          "https://catppuccin.github.io/discord/dist/catppuccin-mocha.theme.css"
        ];
        frameless = true;
        plugins = {
          oneko.enable = true;
        };
      };
    };
  };
}
