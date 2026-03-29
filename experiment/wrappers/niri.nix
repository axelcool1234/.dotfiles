{
  config,
  lib,
  pkgs,
  selfPkgs,
  self,
  wlib,
  ...
}:
let
  useNoctaliaTheme = self.defaults.desktop-shell == "noctalia-shell";
in
{
  imports = [ wlib.wrapperModules.niri ];

  config = {
    escapingFunction = wlib.escapeShellArgWithEnv;

    flags."--config" = lib.mkIf useNoctaliaTheme "$NIRI_RUNTIME_CONFIG";

    # wrapperModules.niri runs `niri validate -c <generated config>`
    # so we need this stub so it won't fail.
    constructFiles.noctaliaStub = lib.mkIf useNoctaliaTheme {
      relPath = "noctalia.kdl";
      content = "";
    };

    runShell = lib.optionals useNoctaliaTheme [
      ''
        runtime_base="${"$"}{XDG_RUNTIME_DIR:-${"$"}{XDG_CACHE_HOME:-${"$"}HOME/.cache}}"
        runtime_dir="$(mktemp -d "$runtime_base/niri-wrapper.XXXXXX")"
        export NIRI_RUNTIME_CONFIG="$runtime_dir/config.kdl"
        cp ${config.constructFiles.generatedConfig.path} "$NIRI_RUNTIME_CONFIG"
        ln -sfn "${"$"}HOME/.config/niri/noctalia.kdl" "$runtime_dir/noctalia.kdl"
      ''
    ];

    settings = {
      extraConfig = lib.optionalString useNoctaliaTheme ''
        include "noctalia.kdl"
      '';

      spawn-at-startup = [
        (lib.getExe selfPkgs.desktop-shell)
      ];

      prefer-no-csd = null;

      input = {
        mod-key = "Ctrl";
      };

      binds = {
        # Menus
        "Mod+SHIFT+D".spawn-sh = "${lib.getExe selfPkgs.noctalia-shell} ipc call launcher toggle";
        "Mod+W".spawn-sh = "${lib.getExe selfPkgs.noctalia-shell} ipc call wallpaper toggle";
        "Mod+Escape".spawn-sh = "${lib.getExe selfPkgs.noctalia-shell} ipc call sessionMenu toggle";
        "Mod+Ctrl+L".spawn-sh = "${lib.getExe selfPkgs.noctalia-shell} ipc call lockScreen lock";

        "Mod+SHIFT+Q".close-window = null;

        # Main Programs
        "Mod+T".spawn = "${lib.getExe selfPkgs.terminal}";
        "Mod+B".spawn = "${lib.getExe selfPkgs.browser}"; 
        "Mod+S".spawn = "${lib.getExe selfPkgs.spicetify}";
        "Mod+D".spawn = "${lib.getExe selfPkgs.nixcord}";

        # Video/Audio Control
        "XF86AudioRaiseVolume".spawn = "${lib.getExe selfPkgs.noctalia-shell} ipc call volume increase";
        "XF86AudioLowerVolume".spawn = "${lib.getExe selfPkgs.noctalia-shell} ipc call volume decrease";
        "XF86AudioMute".spawn = "${lib.getExe selfPkgs.noctalia-shell} ipc call volume muteOutput";
        "XF86AudioMicMute".spawn = "${lib.getExe selfPkgs.noctalia-shell} ipc call volume muteInput";

        "XF86MonBrightnessUp".spawn = "${lib.getExe selfPkgs.noctalia-shell} ipc call brightness increase";
        "XF86MonBrightnessDown".spawn = "${lib.getExe selfPkgs.noctalia-shell} ipc call brightness decrease";

        "Mod+P".spawn = "${lib.getExe pkgs.playerctl} play-pause";
        "Mod+BracketLeft".spawn = "${lib.getExe pkgs.playerctl} previous";
        "Mod+BracketRight".spawn = "${lib.getExe pkgs.playerctl} next";

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
  };
}
