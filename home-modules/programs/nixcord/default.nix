{
  inputs,
  lib,
  config,
  theme,
  ...
}:
with lib;
let
  program = "nixcord";
  program-module = config.modules.${program};
  discordThemeSource = theme.lookupAssetSource "discord";
  discordThemeCss =
    if discordThemeSource == null then
      ""
    else
      builtins.readFile (builtins.toPath "${discordThemeSource}");
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
      dorion.enable = false; # Dorion
      quickCss = discordThemeCss;
      config = {
        useQuickCss = true;
        frameless = true;
        plugins = {
          oneko.enable = true;
        };
      };
    };
  };
}
