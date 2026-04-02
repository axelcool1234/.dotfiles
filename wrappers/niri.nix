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

        noctalia_config="${"$"}HOME/.config/niri/noctalia.kdl"
        if [ -r "$noctalia_config" ]; then
          ln -sfn "$noctalia_config" "$runtime_dir/noctalia.kdl"
        else
          cp ${config.constructFiles.noctaliaStub.path} "$runtime_dir/noctalia.kdl"
        fi
      ''
    ];

    settings = {
      spawn-at-startup = [
        (lib.getExe selfPkgs.desktop-shell)
      ];

      prefer-no-csd = {};

      binds = {
        # Menus
        "Mod+SHIFT+D".spawn-sh = "${lib.getExe selfPkgs.noctalia-shell} ipc call launcher toggle";
        "Mod+W".spawn-sh = "${lib.getExe selfPkgs.noctalia-shell} ipc call wallpaper toggle";
        "Mod+Escape".spawn-sh = "${lib.getExe selfPkgs.noctalia-shell} ipc call sessionMenu toggle";
        "Mod+Ctrl+L".spawn-sh = "${lib.getExe selfPkgs.noctalia-shell} ipc call lockScreen lock";

        "Mod+SHIFT+Q".close-window = {};

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
        "Mod+H".focus-column-left = {};
        "Mod+J".focus-window-down = {};
        "Mod+K".focus-window-up = {};
        "Mod+L".focus-column-right = {};

        "Mod+F".maximize-column = {};

        "Mod+1".focus-workspace = "w01";
        "Mod+2".focus-workspace = "w02";
        "Mod+3".focus-workspace = "w03";
        "Mod+4".focus-workspace = "w04";
        "Mod+5".focus-workspace = "w05";
        "Mod+6".focus-workspace = "w06";
        "Mod+7".focus-workspace = "w07";
        "Mod+8".focus-workspace = "w08";
        "Mod+9".focus-workspace = "w09";
        "Mod+0".focus-workspace = "w10";

        "Mod+Shift+1".move-column-to-workspace = "w01";
        "Mod+Shift+2".move-column-to-workspace = "w02";
        "Mod+Shift+3".move-column-to-workspace = "w03";
        "Mod+Shift+4".move-column-to-workspace = "w04";
        "Mod+Shift+5".move-column-to-workspace = "w05";
        "Mod+Shift+6".move-column-to-workspace = "w06";
        "Mod+Shift+7".move-column-to-workspace = "w07";
        "Mod+Shift+8".move-column-to-workspace = "w08";
        "Mod+Shift+9".move-column-to-workspace = "w09";
        "Mod+Shift+0".move-column-to-workspace = "w10";
      };
      workspaces = {
        w01 = { };
        w02 = { };
        w03 = { };
        w04 = { };
        w05 = { };
        w06 = { };
        w07 = { };
        w08 = { };
        w09 = { };
        w10 = { };
      };
      window-rule = {
        open-maximized = true;
      };

      xwayland-satellite.path = lib.getExe pkgs.xwayland-satellite;

      extraConfig = lib.optionalString useNoctaliaTheme ''
        include "noctalia.kdl"
      '';
    };
  };
}
