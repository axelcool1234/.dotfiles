{
  config,
  lib,
  pkgs,
  ...
}:

{
  config = lib.mkIf config.hyprland.enable {
    # Systemd services setup
    systemd.packages = with pkgs; [
      auto-cpufreq
    ];

    # Enable Services
    services.geoclue2.enable = true;
    services.upower.enable = true;
    programs.dconf.enable = true;
    services.dbus = {
      enable = true;
      implementation = "broker";
    };
    programs.xfconf.enable = true;
    services.tumbler.enable = true;
    services.fwupd.enable = true;
    services.auto-cpufreq.enable = true; # automatic CPU speed and power optimizer for Linux

    # Automount rules (just configured for my split keyboard right now)
    services.udev.extraRules = ''
      # Automount RP2040 bootloader volume (RPI-RP2)
      SUBSYSTEMS=="usb", SUBSYSTEM=="block", ACTION=="add", ENV{ID_FS_LABEL}=="RPI-RP2", RUN+="${pkgs.writeShellScript "udev-rpi-mount.sh" ''
        ${pkgs.systemd}/bin/systemd-mount --no-block --automount=yes --collect --options=X-mount.mkdir "$DEVNAME" "/run/media/$ID_FS_LABEL"
      ''}"
      SUBSYSTEMS=="usb", SUBSYSTEM=="block", ACTION=="remove", ENV{ID_FS_LABEL}=="RPI-RP2", RUN+="${pkgs.writeShellScript "udev-rpi-unmount.sh" ''
        ${pkgs.systemd}/bin/systemd-umount "$DEVNAME" "/run/media/$ID_FS_LABEL"
        ${pkgs.coreutils}/bin/rmdir "/run/media/$ID_FS_LABEL"
      ''}"
    '';

    environment.systemPackages = with pkgs; [
      # Hyprland
      pyprland # Additional Hyprland Plugins
      hyprpicker # Color Picker
      hyprcursor # Cursor themes
      hyprpaper # Wallpaper Daemon

      # General System Stuff
      psi-notify # System Resource Alerter
      poweralertd # Power Alerter
      playerctl # Audio Control
      grim # Screenshot
      slurp # Screenshot
      wl-screenrec # Recording
      wl-clipboard # Clipboard
      cliphist # Clipboard
      wl-clip-persist # Clipboard
      psmisc # Terminal utils (used in some scripts)
      wtype # Terminal util  (used in some scripts)
      ffmpeg_6-full # Terminal util  (used in recording script)

      at-spi2-atk
      qt6.qtwayland
    ];

    # Security
    security.pam.services.hyprlock = { };
  };
}
