{ pkgs, lib, ... }:
{
  imports = [
    ./grub.nix
    ./gc.nix
    ./auto-upgrade.nix
    ./gnome.nix
    ./hyprland
    ./docker.nix
    ./sound.nix # only parts of it are under .enable
    ./users.nix # no need for .enable option
    ./internationalisation.nix # no need for .enable option
    ./printing.nix # no need for .enable option
    ./time.nix # no need for .enable option
    ./bluetooth.nix # no need for .enable option
    ./networking.nix # no need for .enable option
    ./nix-settings.nix # no need for .enable option
    ./fonts.nix # no need for .enable option
  ];

  # Bootloader
  grub.enable = lib.mkDefault true;

  # Auto update and auto garbage collect
  gc.enable = lib.mkDefault true;
  auto-upgrade.enable = lib.mkDefault false; # WARNING: MODULE IS NOT PROPERLY CONFIGURED YET!!!!

  # System-level sound packages
  sound-control.enable = lib.mkDefault true;

  # Docker service
  docker.enable = lib.mkDefault false; # WARNING: Docker does NOT work well with nftables because Docker internally uses iptables!

  # Desktop Environment
  gnome.enable = lib.mkDefault false;
  hyprland.enable = lib.mkDefault true;
}
