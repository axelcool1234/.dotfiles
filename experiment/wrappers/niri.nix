{
  lib,
  pkgs,
  selfPkgs,
  wlib,
  ...
}:
{
  imports = [ wlib.wrapperModules.niri ];

  config.settings = {
    spawn-at-startup = [
      (lib.getExe selfPkgs.desktop-shell)
    ];

    prefer-no-csd = null;

    input = {
      mod-key = "Ctrl";
    };

    binds = {
      "Mod+SHIFT+Q".close-window = null;
      "Mod+SHIFT+D".spawn-sh = "${lib.getExe selfPkgs.noctalia-shell} ipc call launcher toggle";

      "Mod+T".spawn = "${lib.getExe selfPkgs.terminal}";
      "Mod+B".spawn = "${lib.getExe selfPkgs.browser}"; 
      "Mod+S".spawn = "${lib.getExe selfPkgs.spicetify}";
      "Mod+D".spawn = "${lib.getExe selfPkgs.nixcord}";

      # Movement
      "Mod+H".focus-column-left = null;
      "Mod+J".focus-window-down = null;
      "Mod+K".focus-window-up = null;
      "Mod+L".focus-column-right = null;

      "Mod+1".focus-workspace = "w0";
      "Mod+2".focus-workspace = "w1";
      "Mod+3".focus-workspace = "w2";
      "Mod+4".focus-workspace = "w3";
      "Mod+5".focus-workspace = "w4";
      "Mod+6".focus-workspace = "w5";
      "Mod+7".focus-workspace = "w6";
      "Mod+8".focus-workspace = "w7";
      "Mod+9".focus-workspace = "w8";
      "Mod+0".focus-workspace = "w9";

      "Mod+Shift+1".move-column-to-workspace = "w0";
      "Mod+Shift+2".move-column-to-workspace = "w1";
      "Mod+Shift+3".move-column-to-workspace = "w2";
      "Mod+Shift+4".move-column-to-workspace = "w3";
      "Mod+Shift+5".move-column-to-workspace = "w4";
      "Mod+Shift+6".move-column-to-workspace = "w5";
      "Mod+Shift+7".move-column-to-workspace = "w6";
      "Mod+Shift+8".move-column-to-workspace = "w7";
      "Mod+Shift+9".move-column-to-workspace = "w8";
      "Mod+Shift+0".move-column-to-workspace = "w9";
    };

    xwayland-satellite.path = lib.getExe pkgs.xwayland-satellite;
  };
}
