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
    xdg.configFile.xsettingsd.source = ./xsettingsd;
    xdg.configFile.xfce4.source = ./xfce4;
    xdg.configFile.wpaperd.source = ./wpaperd;
    xdg.configFile.Thunar.source  = ./Thunar;
    xdg.configFile."gtk-3.0".source  = ./gtk-3.0;
    xdg.configFile."gtk-4.0".source  = ./gtk-4.0;
    xdg.configFile.autostart.source  = ./autostart;
    xdg.configFile.swappy.source  = ./swappy;
    xdg.configFile.zellij.source  = ./zellij;    
    xdg.configFile.Kvantum.source  = ./Kvantum;
    home.file.".icons".source = ./.icons;
    home.file.".gtkrc-2.0".source = ./.gtkrc-2.0;  
    home.file.".face".source = ./.face;
  };
}
