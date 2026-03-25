{
  self,
  inputs,
  lib,
  pkgs,
  ...
}:
(inputs.wrappers.wrapperModules.kitty.apply {
  inherit pkgs;

  settings = {
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
      "ctrl+shift+e launch --title=scrollback --type=overlay --stdin-source=@screen_scrollback ${lib.getExe self.packages.${pkgs.stdenv.hostPlatform.system}.editor}"
    ];
  };
}).wrapper
