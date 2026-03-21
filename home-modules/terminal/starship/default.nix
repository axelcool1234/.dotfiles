{ pkgs, lib, config, theme, ... }:
with lib;
let
  program = "starship";
  program-module = config.modules.${program};
  starshipConfig = pkgs.writeText "starship.toml" ''
    palette = "${theme.starship.paletteName}"

    [palettes.${theme.starship.paletteName}]
    rosewater = "${theme.hex "rosewater"}"
    flamingo = "${theme.hex "flamingo"}"
    pink = "${theme.hex "pink"}"
    mauve = "${theme.hex "mauve"}"
    red = "${theme.hex "red"}"
    maroon = "${theme.hex "maroon"}"
    peach = "${theme.hex "peach"}"
    yellow = "${theme.hex "yellow"}"
    green = "${theme.hex "green"}"
    teal = "${theme.hex "teal"}"
    sky = "${theme.hex "sky"}"
    sapphire = "${theme.hex "sapphire"}"
    blue = "${theme.hex "blue"}"
    lavender = "${theme.hex "lavender"}"
    text = "${theme.hex "text"}"
    subtext1 = "${theme.hex "subtext1"}"
    subtext0 = "${theme.hex "subtext0"}"
    overlay2 = "${theme.hex "overlay2"}"
    overlay1 = "${theme.hex "overlay1"}"
    overlay0 = "${theme.hex "overlay0"}"
    surface2 = "${theme.hex "surface2"}"
    surface1 = "${theme.hex "surface1"}"
    surface0 = "${theme.hex "surface0"}"
    base = "${theme.hex "base"}"
    mantle = "${theme.hex "mantle"}"
    crust = "${theme.hex "crust"}"
  '';
in
{
  options.modules.${program} = {
    enable = mkEnableOption "enables ${program} config";
  };
  config = mkIf program-module.enable {
    programs.${program}.enable = true;
    xdg.configFile."${program}/starship.toml".source = starshipConfig;
  };
}
