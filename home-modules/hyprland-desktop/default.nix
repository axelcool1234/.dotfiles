{ pkgs, lib, config, ... }: {
  options = {
    hyprland.enable =
      lib.mkEnableOption "enables hyprland config";
  };
  config = lib.mkIf config.hyprland.enable {
    xdg.configFile.hypr.source = ./hyprland;
    xdg.configFile.waybar.source = ./waybar;
    # Wayland packages
    home.packages = with pkgs; [
      hyprland     # Compositor

      kitty        # Terminal WARNING: Temporary until Wezterm works.
      bottom       # See System Health
      btop         # See System Health

      tre-command  # Tree Command
      lsof         # Lists Open Files
      psi-notify   # System Resource Alerter
      poweralertd  # Power Alerter
      pyprland     # Additional Hyprland Plugins
      playerctl    # Audio Control
      waybar       # Bar
      dunst        # Notification
      rofi-wayland # Launcher
      avizo        # OSD (on-screen display) aka notification daemon
      gammastep    # Color Temperature
      xfce.thunar  # File Manager
      mpv          # Media Player
      imv          # Image Viewer
      zathura      # PDF Viewer
      swappy       # Image Editor
      grim         # Screenshot
      slurp        # Screenshot
      wf-recorder  # Recording
      hyprpicker   # Color Picker
      wl-clipboard # Clipboard
      cliphist     # Clipboard
      clipboard-jh # Clipboard
      swayidle     # Idle Management Daemon
      swaylock     # Screen Locker
      wlogout      # Logout menu
      wpaperd      # Wallpaper Daemon
      wlogout      # Logout Menu
    ];
  };
}
