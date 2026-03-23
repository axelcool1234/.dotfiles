{ lib, config, desktop, theme, ... }:
with lib;
let
  program = "dunst";
  program-module = config.modules.${program};
  themeFonts = theme.requireThemeData "fonts";
  dunstAssetSource = theme.lookupAssetSource program;
in
{
  options.modules.${program} = {
    enable = mkEnableOption "enables ${program} config";
  };

  config = mkIf (program-module.enable && desktop == "hyprland") (
    mkMerge [
      {
        services.dunst.enable = true;
        xdg.configFile."dunst/dunstrc".text = ''
          [global]
          font = "${themeFonts.notifications.name} ${toString themeFonts.notifications.size}"
          corner_radius = 10
          offset = 5x5
          origin = top-right
          notification_limit = 8
          gap_size = 7
          frame_width = 2
          width = 300
          height = 100
        '';
      }
      (lib.optionalAttrs (dunstAssetSource != null) {
        xdg.configFile."dunst/dunstrc.d/${theme.source.family}.conf".source = dunstAssetSource;
      })
    ]
  );
}
