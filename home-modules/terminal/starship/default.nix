{ lib, config, theme, ... }:
with lib;
let
  program = "starship";
  program-module = config.modules.${program};
  starshipProvider = theme.providerFor "starship";
  starshipThemeSource = theme.resolveAssetSource starshipProvider;

  starshipThemeText =
    if starshipProvider != null
      && starshipProvider.type == "template"
      && starshipProvider.options ? paletteName
      && starshipProvider.options ? colors then
      ''
        palette = "${starshipProvider.options.paletteName}"

        [palettes.${starshipProvider.options.paletteName}]
      ''
      + lib.concatStringsSep "\n" (
        lib.mapAttrsToList (name: value: "${name} = \"${value}\"") starshipProvider.options.colors
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
    xdg.configFile =
      if starshipThemeSource != null then
        { "starship.toml".source = starshipThemeSource; }
      else if starshipThemeText != null then
        { "starship.toml".text = starshipThemeText; }
      else if theme.isHandledByStylix starshipProvider then
        { }
      else
        throw "theme.apps.starship must use either an asset or template provider";
  };
}
