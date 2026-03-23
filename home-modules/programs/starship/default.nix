{ lib, config, theme, ... }:
with lib;
let
  program = "starship";
  program-module = config.modules.${program};
  starshipThemeSource = theme.lookupAssetSource program;

  starshipThemeText =
    if theme.providerIsStructured program then
      ''
        palette = "${theme.requireStructuredOption program "paletteName"}"

        [palettes.${theme.requireStructuredOption program "paletteName"}]
      ''
      + lib.concatStringsSep "\n" (
        lib.mapAttrsToList (name: value: "${name} = \"${value}\"") (theme.requireStructuredOption program "colors")
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
      else if theme.ifNotHandledByStylix program (_: true) == null then
        { }
      else
        throw "theme.apps.starship must use either an asset or structured provider";
  };
}
