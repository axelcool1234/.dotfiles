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
      null;

  starshipThemeText =
    if starshipProvider != null
      && starshipProvider.type == "template"
      && starshipProvider.options ? paletteName
      && starshipProvider.options ? palette then
      ''
        palette = "${starshipProvider.options.paletteName}"

        [palettes.${starshipProvider.options.paletteName}]
      ''
      + lib.concatStringsSep "\n" (
        lib.mapAttrsToList (name: value: "${name} = \"${value}\"") starshipProvider.options.palette
      )
      + "\n"
    else
      null;
in
{
  options.modules.${program} = {
    enable = mkEnableOption "enables ${program} config";
  };
  config = mkIf program-module.enable {
    programs.${program}.enable = true;
    xdg.configFile."starship.toml" =
      if starshipThemeSource != null then
        { source = starshipThemeSource; }
      else if starshipThemeText != null then
        { text = starshipThemeText; }
      else
        throw "theme.apps.starship must use either an asset or template provider";
  };
}
