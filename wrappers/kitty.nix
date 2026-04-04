{
  config,
  hostVars,
  lib,
  pkgs,
  selfPkgs,
  wlib,
  ...
}:
let
  useNoctaliaTheme = hostVars.desktop-shell == "noctalia-shell";
  terminalFont = hostVars.fonts.terminal;
  symbolFont = hostVars.fonts.symbols;
  postscriptSuffix = lib.optionalString (terminalFont.postscriptName != null) " postscript_name=${terminalFont.postscriptName}";

  kittyKeyValue = {
    listsAsDuplicateKeys = true;
    mkKeyValue = lib.generators.mkKeyValueDefault { } " ";
  };

  kittyKeyValueFormat = pkgs.formats.keyValue kittyKeyValue; 
in
{
  imports = [ wlib.modules.default ];

  options = {
    settings = lib.mkOption {
      type = kittyKeyValueFormat.type;
      default = { };
      description = ''
        Configuration for kitty.
        The fast, feature-rich, GPU based terminal emulator.
      '';
    };

    extraSettings = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = ''
        Extra lines appended to the config file.
        This can be used to maintain order for settings.
      '';
    };
  };

  config = {
    package = pkgs.kitty;

    env.KITTY_CONFIG_DIRECTORY = dirOf config.constructFiles.generatedConfig.path;

    constructFiles.generatedConfig = {
      relPath = "kitty.conf";
      content =
        lib.generators.toKeyValue kittyKeyValue config.settings
        + lib.optionalString (config.extraSettings != "") "\n${config.extraSettings}\n";
    };

    settings = {
      # The shell program to execute and the editor to use.
      shell = lib.getExe selfPkgs.environment;
      editor = lib.getExe selfPkgs.${hostVars.editor};

      # Centralize terminal typography so wrapped terminal apps inherit the
      # same monospace choice.
      font_family = "family='${terminalFont.family}'${postscriptSuffix}";
      symbol_map = [
        "U+e738,U+e256,U+db82,U+df37,U+2615,U+279c,U+2718,U+21e1,U+2638,U+25ac ${symbolFont.family}"
        "U+23FB-U+23FE,U+2665,U+26A1,U+2B58,U+E000-U+E00A,U+E0A0-U+E0A3,U+E0B0-U+E0D4,U+E200-U+E2A9,U+E300-U+E3E3,U+E5FA-U+E6AA,U+E700-U+E7C5,U+EA60-U+EBEB,U+F000-U+F2E0,U+F300-U+F32F,U+F400-U+F4A9,U+F500-U+F8FF,U+F0001-U+F1AF0 ${symbolFont.family}"
      ];

      # Disable cursor blinking.
      cursor_blink_interval = 0;

      # Tabs are shown as a continuous line with fancy separators.
      tab_bar_style = "powerline";
      tab_powerline_style = "round";

      # Allow other programs to control Kitty remotely.
      allow_remote_control = "yes";

      # Enable shell integration features for interactive shells.
      shell_integration = "enabled";

      # Keymap.
      map = [
        "ctrl+t new_tab_with_cwd"
        "ctrl+h previous_tab"
        "ctrl+l next_tab"
        "ctrl+shift+e launch --title=scrollback --type=overlay --stdin-source=@screen_scrollback ${lib.getExe selfPkgs.${hostVars.editor}}"
      ];
    } // lib.optionalAttrs (terminalFont.size != null) {
      font_size = terminalFont.size;
    };

    # Noctalia handles Kitty's theme
    extraSettings = lib.mkAfter (lib.optionalString useNoctaliaTheme ''
      include ~/.config/kitty/themes/noctalia.conf
    '');

    meta.platforms = lib.platforms.linux;
  };
}
