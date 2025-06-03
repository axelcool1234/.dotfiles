{ config, lib, pkgs, ... }:

{
  config = lib.mkIf config.hyprland.enable {
    # Systemd services setup
    systemd.packages = with pkgs; [
      auto-cpufreq
    ];

    # Enable Services
    services.geoclue2.enable = true;
    programs.direnv.enable = true;
    services.upower.enable = true;
    programs.fish.enable = true;
    programs.dconf.enable = true;
    services.dbus.enable = true;
    services.dbus.packages = with pkgs; [
    	xfce.xfconf
    	gnome2.GConf
    ];
    services.mpd.enable = true;
    programs.thunar.enable = true;
    programs.xfconf.enable = true;
    services.tumbler.enable = true; 
    services.fwupd.enable = true;
    services.auto-cpufreq.enable = true;
    # services.udev.packages = with pkgs; [ gnome.gnome-settings-daemon ];

    environment.systemPackages = with pkgs; [
      bottom          # See System Health
      btop            # See System Health
      tre-command     # Tree Command
      lsof            # Lists Open Files
      psi-notify      # System Resource Alerter
      poweralertd     # Power Alerter
      pyprland        # Additional Hyprland Plugins
      playerctl       # Audio Control
      waybar          # Bar
      dunst           # Notification
      rofi-wayland    # Launcher
      avizo           # OSD (on-screen display) aka notification daemon
      xfce.thunar     # File Manager
      mpv             # Media Player
      imv             # Image Viewer
      zathura         # PDF Viewer
      swappy          # Image Editor
      grim            # Screenshot
      slurp           # Screenshot
      wl-screenrec    # Recording
      hyprpicker      # Color Picker
      wl-clipboard    # Clipboard
      cliphist        # Clipboard
      wl-clip-persist # Clipboard
      hyprlock        # Screen Locker
      hypridle        # Idle Management Daemon
      wlogout         # Logout menu
      hyprpaper       # Wallpaper Daemon
      wlogout         # Logout Menu

      at-spi2-atk
      qt6.qtwayland
      psmisc # Terminal utils
      xdg-utils # Terminal utils
      wlrctl # Terminal utils
      gifsicle # Terminal utils
      imagemagick
      ffmpeg_6-full
      wtype
      wlr-randr
      gpu-viewer
    ];

    # Security
    security.pam.services.hyprlock = {};
  };
}
