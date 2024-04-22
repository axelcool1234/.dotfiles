{ config, lib, pkgs, ... }:
{
  options = {
    gnome.enable =
      lib.mkEnableOption "enables gnome";
  };
  config = lib.mkIf config.gnome.enable {
    services.xserver = {
      # Enable the X11 windowing system.
      enable = true;

      # Enable the GNOME Desktop Environment.
      displayManager.gdm.enable = true;
      desktopManager.gnome.enable = true;

      # Configure keymap in X11
      xkb.layout = "us";
      xkb.variant = "";
    };

    # Gnome Exclude Packages
    # environment.gnome.excludePackages = (with pkgs; [
    #   gnome-tour
    # ]) ++ (with pkgs.gnome; [
    #       gnome-terminal
    #       gedit # text editor
    #       epiphany # web browser
    #       geary # email reader
    #       tali # poker game
    #       iagno # go game
    #       hitori # sudoku game
    #       atomix # puzzle game
    # ]);
  };
}
