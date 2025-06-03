{ pkgs, config, lib, inputs, ... }: 
{
  options = {
    hyprland.enable = 
      lib.mkEnableOption "enables hyprland and services";
  };
  config = lib.mkIf config.hyprland.enable {
    # Enable the Hyprland Environment
    programs.hyprland = {
      # Install the packages from nixpkgs
      enable = true;

      # Better Systemd integration
      withUWSM = true;

      # Uses the flake package of hyprland
      package = inputs.hyprland.packages.${pkgs.system}.hyprland;
  
      # Whether to enable XWayland
      xwayland.enable = true;
    };
    environment.sessionVariables.NIXOS_OZONE_WL = "1";
    environment.sessionVariables.WLR_NO_HARDWARE_CURSORS = "1";

    programs.hyprlock.enable = true;
    services.hypridle.enable = true;
  };
}
