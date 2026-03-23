{ pkgs, lib, config, theme, ... }:
with lib;
let
  program = "rofi";
  program-module = config.modules.${program};
  rofiProvider = theme.lookupProvider program;
  rofiAssetSource = theme.ifNotHandledByStylix rofiProvider theme.lookupAssetSource;
  rofiColors = theme.lookupProviderOption rofiProvider "colors";
  themeFonts = theme.requireThemeData "fonts";
  renderRasiColorVariables = colors: ''
    * {
    ${lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: value: "  ${name}: ${value};") colors
    )}
    }
  '';
  rofiThemeText =
    if rofiColors != null then
      renderRasiColorVariables rofiColors
      + "\n"
      + ''
        * {
          font: "${themeFonts.popups.name} ${toString themeFonts.popups.size}";
        }
      ''
    else
      null;
  rofiThemeWrapper =
    let
      inherit (config.lib.formats.rasi) mkLiteral;
    in
    {
      "@theme" = "~/.config/dotfiles-theme/rofi.rasi";

      "*" = {
        "bg-col" = mkLiteral "@base";
        "bg-col-light" = mkLiteral "@base";
        "border-col" = mkLiteral "@base";
        "selected-col" = mkLiteral "@base";
        "fg-col" = mkLiteral "@text";
        "fg-col2" = mkLiteral "@red";
        grey = mkLiteral "@overlay0";
        width = 600;
        "border-radius" = mkLiteral "15px";
      };

      "element-text, element-icon , mode-switcher" = {
        "background-color" = mkLiteral "inherit";
        "text-color" = mkLiteral "inherit";
      };

      window = {
        height = 360;
        border = 2;
        "border-color" = mkLiteral "@teal";
        "background-color" = mkLiteral "@bg-col";
      };

      mainbox = {
        "background-color" = mkLiteral "@bg-col";
      };

      inputbar = {
        children = map mkLiteral [ "prompt" "entry" ];
        "background-color" = mkLiteral "@bg-col";
        "border-radius" = 5;
        padding = 2;
      };

      prompt = {
        "background-color" = mkLiteral "@blue";
        padding = 6;
        "text-color" = mkLiteral "@bg-col";
        "border-radius" = 3;
        margin = mkLiteral "20px 0px 0px 20px";
      };

      "textbox-prompt-colon" = {
        expand = false;
        str = ":";
      };

      entry = {
        padding = 6;
        margin = mkLiteral "20px 0px 0px 10px";
        "text-color" = mkLiteral "@fg-col";
        "background-color" = mkLiteral "@bg-col";
      };

      listview = {
        border = mkLiteral "0px 0px 0px";
        padding = mkLiteral "6px 0px 0px";
        margin = mkLiteral "10px 0px 0px 20px";
        columns = 2;
        lines = 5;
        "background-color" = mkLiteral "@bg-col";
      };

      element = {
        padding = 5;
        "background-color" = mkLiteral "@bg-col";
        "text-color" = mkLiteral "@fg-col";
      };

      "element-icon" = {
        size = mkLiteral "25px";
      };

      "element selected" = {
        "background-color" = mkLiteral "@selected-col";
        "text-color" = mkLiteral "@teal";
      };

      "mode-switcher" = {
        spacing = 0;
      };

      button = {
        padding = 10;
        "background-color" = mkLiteral "@bg-col-light";
        "text-color" = mkLiteral "@grey";
        "vertical-align" = mkLiteral "0.5";
        "horizontal-align" = mkLiteral "0.5";
      };

      "button selected" = {
        "background-color" = mkLiteral "@bg-col";
        "text-color" = mkLiteral "@blue";
      };

      message = {
        "background-color" = mkLiteral "@bg-col-light";
        margin = 2;
        padding = 2;
        "border-radius" = 5;
      };

      textbox = {
        padding = 6;
        margin = mkLiteral "20px 0px 0px 20px";
        "text-color" = mkLiteral "@blue";
        "background-color" = mkLiteral "@bg-col-light";
      };
    };
in
{
  options.modules.${program} = {
    enable = mkEnableOption "enables ${program} config";
  };

  config = mkIf program-module.enable (
    mkMerge [
      {
        programs.rofi =
          {
            enable = true;
            package = pkgs.rofi;
            extraConfig = {
              modi = "drun";
              "icon-theme" = "Numix-Circle";
              "show-icons" = true;
              terminal = "kitty";
              "drun-display-format" = "{icon} {name}";
              location = 0;
              "disable-history" = false;
              "hide-scrollbar" = true;
              "display-drun" = "   Apps ";
              "sidebar-mode" = true;
              "border-radius" = 10;
            };
            theme = rofiThemeWrapper;
          };
      }
      (lib.optionalAttrs theme.isStylix {
        # there are conflicts between stylix theme and
        # custom one defined by stylix palette
        stylix.targets.rofi.enable = false;
      })
      (lib.optionalAttrs (rofiAssetSource != null) {
        xdg.configFile."${rofiProvider.target}".source = rofiAssetSource;
      })
      (lib.optionalAttrs (rofiAssetSource == null && rofiThemeText != null) {
        xdg.configFile."dotfiles-theme/rofi.rasi".text = rofiThemeText;
      })
    ]
  );
}
