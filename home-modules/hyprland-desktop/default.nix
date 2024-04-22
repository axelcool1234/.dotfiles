{ pkgs, lib, config, ... }: {
  options = {
    hyprland.enable =
      lib.mkEnableOption "enables hyprland config";
  };
  config = lib.mkIf config.hyprland.enable {
    xdg.configFile.hypr.source = ./hyprland;
    xdg.configFile.waybar.source = ./waybar;
    xdg.configFile.dunst.source = ./dunst;
    xdg.configFile.mpv.source = ./mpv;
    xdg.configFile.rofi.source = ./rofi;
    xdg.configFile.wlogout.source = ./wlogout;
    xdg.configFile.swayidle.source = ./swayidle;
    xdg.configFile.swaylock.source = ./swaylock;
    xdg.configFile.avizo.source = ./avizo;
  };
}
