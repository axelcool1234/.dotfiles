{ lib, config, theme, ... }:
with lib;
let
  program = "kitty";
  program-module = config.modules.${program};
  kittyThemeSource = theme.lookupAssetSource program;

  # Kitty only includes an external theme file when the selected provider is an
  # asset-backed theme with a realized target path.
  kittyThemeTarget = theme.matchProvider program {
    null = null;
    asset = provider: provider.target;
    default = _: null;
  };
  themeFonts = theme.requireThemeData "fonts";
  themeIncludeLine = lib.optionalString (kittyThemeTarget != null) "include ~/.config/${kittyThemeTarget}\n";

  # Build the font-specific section inline so Kitty always uses the terminal
  # and symbol fonts selected by the active theme bundle.
  kittyFontConfigText =
    let
      postscriptSuffix =
        if themeFonts.terminal ? postscriptName then
          " postscript_name=${themeFonts.terminal.postscriptName}"
        else
          "";
    in
    ''
      # Fonts
      font_size ${toString themeFonts.terminal.size}
      symbol_map U+e738,U+e256,U+db82,U+df37,U+2615,U+279c,U+2718,U+21e1,U+2638,U+25ac  ${themeFonts.symbols.name}
      symbol_map U+23FB-U+23FE,U+2665,U+26A1,U+2B58,U+E000-U+E00A,U+E0A0-U+E0A3,U+E0B0-U+E0D4,U+E200-U+E2A9,U+E300-U+E3E3,U+E5FA-U+E6AA,U+E700-U+E7C5,U+EA60-U+EBEB,U+F000-U+F2E0,U+F300-U+F32F,U+F400-U+F4A9,U+F500-U+F8FF,U+F0001-U+F1AF0 ${themeFonts.symbols.name}
      font_family      family='${themeFonts.terminal.family}'${postscriptSuffix}
      bold_font        auto
      italic_font      auto
      bold_italic_font auto

    '';

  # Prepend the generated font block to the base Kitty config and keep the
  # external theme include only when a non-Stylix theme asset should be loaded.
  kittyConfigText =
    let
      text = builtins.readFile ./kitty.conf;
    in
    kittyFontConfigText
    + lib.replaceStrings
      [ themeIncludeLine ]
      [ (if theme.ifNotHandledByStylix program (_: true) == null then "" else themeIncludeLine) ]
      text;
in
{
  options.modules.${program} = {
    enable = mkEnableOption "enables ${program} config";
  };
  config = mkIf program-module.enable {
    programs.${program}.enable = true;
    xdg.configFile = {
      "${program}/kitty.conf".text = kittyConfigText;
      "${program}/custom-hints.py".source = ./custom-hints.py;
      "${program}/flash-marks.py".source = ./flash-marks.py;
      "${program}/quick-access-terminal.conf".source = ./quick-access-terminal.conf;
    } // lib.optionalAttrs (kittyThemeSource != null && kittyThemeTarget != null) {
      "${kittyThemeTarget}".source = kittyThemeSource;
    };
  };
}
