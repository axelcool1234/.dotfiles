{ lib, ... }:
{
  imports = [
    ./hyprland-desktop
    ./terminal/wezterm
    ./terminal/kitty
    ./terminal/fish
    ./terminal/nushell
    ./terminal/starship
    ./terminal/btop
    ./terminal/neofetch
    ./terminal/neovim
    ./terminal/helix
    ./terminal/git
    ./terminal/lazygit
    ./programs/firefox
    ./programs/nixcord
    ./programs/spicetify
    ./programs/zathura
  ];
}
