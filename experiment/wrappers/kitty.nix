{
  config,
  lib,
  pkgs,
  self,
  selfPkgs,
  wlib,
  ...
}:
let
  useNoctaliaTheme = self.defaults.desktop-shell == "noctalia-shell";

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
      editor = lib.getExe selfPkgs.editor;

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
        "ctrl+shift+e launch --title=scrollback --type=overlay --stdin-source=@screen_scrollback ${lib.getExe selfPkgs.editor}"
      ];
    };

    # Noctalia handles Kitty's theme
    extraSettings = lib.mkAfter (lib.optionalString useNoctaliaTheme ''
      include ~/.config/kitty/themes/noctalia.conf
    '');

    meta.platforms = lib.platforms.linux;
  };
}
