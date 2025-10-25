{
  inputs,
  pkgs,
  lib,
  config,
  ...
}:
{
  imports = [
    inputs.nixcord.homeModules.nixcord
  ];
  options = {
    nixcord.enable = lib.mkEnableOption "enables nixcord config";
  };
  config = lib.mkIf config.nixcord.enable {
    # https://kaylorben.github.io/nixcord/
    programs.nixcord = {
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
