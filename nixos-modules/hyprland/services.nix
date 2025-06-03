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
    services.dbus = {
      enable = true;
      implementation = "broker";
      packages = with pkgs; [
        xfce.xfconf
        gnome2.GConf
      ];
    };
    services.mpd.enable = true;
    programs.thunar.enable = true;
    programs.xfconf.enable = true;
    services.tumbler.enable = true; 
    services.fwupd.enable = true;
    services.auto-cpufreq.enable = true;
    # services.udev.packages = with pkgs; [ gnome.gnome-settings-daemon ];

    environment.systemPackages = with pkgs; [
      # Hyprland
      pyprland        # Additional Hyprland Plugins
      hyprpicker      # Color Picker
      hyprcursor      # Cursor themes
      hyprlock        # Screen Locker
      hypridle        # Idle Management Daemon
      hyprpaper       # Wallpaper Daemon

      # General System Stuff
      btop            # See System Health
      psi-notify      # System Resource Alerter
      poweralertd     # Power Alerter
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
      wl-clipboard    # Clipboard
      cliphist        # Clipboard
      wl-clip-persist # Clipboard
      wlogout         # Logout menu
      psmisc          # Terminal utils (used in some scripts)
      wlrctl          # Terminal utils (just really cool, good potential scripting here)
      wtype           # Terminal util  (used in some scripts)
      ffmpeg_6-full   # Terminal util  (used in recording script)

      at-spi2-atk
      qt6.qtwayland
    ];

    # Security
    security.pam.services.hyprlock = {};
  };
}
