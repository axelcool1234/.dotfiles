{ config, lib, ... }: {
  imports = [
    ./hyprland.nix
    ./screen.nix
    ./services.nix
  ];
}
