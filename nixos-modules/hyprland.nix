{ pkgs, lib, config, inputs, ... }: 
{
  options = {
    hyprland.enable =
      lib.mkEnableOption "enables hyprland";
  };
  config = lib.mkIf config.hyprland.enable {
    # Enable the Hyprland Environment
    # programs.hyprland = {
    #   # Install the packages from nixpkgs
    #   enable = true;

    #   # Uses the flake package of hyprland
    #   package = inputs.hyprland.packages.${pkgs.system}.hyprland;
    
    #   # Whether to enable XWayland
    #   xwayland.enable = true;
    # };
  };
}
