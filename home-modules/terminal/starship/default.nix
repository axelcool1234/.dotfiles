{ lib, config, themes, theme, ... }:
with lib;
let
  program = "starship";
  program-module = config.modules.${program};
  starshipProvider = themes.helpers.getAppProvider theme "starship";
  starshipThemeSource =
    if starshipProvider != null && starshipProvider.type == "asset" then
      themes.helpers.resolveAssetSource starshipProvider
    else
      throw "theme.apps.starship must fetch an upstream theme asset";
in
{
  options.modules.${program} = {
    enable = mkEnableOption "enables ${program} config";
  };
  config = mkIf program-module.enable {
    programs.${program}.enable = true;
    xdg.configFile."starship.toml".source = starshipThemeSource;
  };
}
