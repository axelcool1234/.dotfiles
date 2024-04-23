{ config, lib, ... }: {
  imports = [
    ./hyprland.nix
    ./screen.nix
    ./theme.nix
    ./services.nix
    ./display-manager.nix
  ];
}
