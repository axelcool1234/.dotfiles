{ pkgs, lib, ... }: {
  imports = [
    ./terminal/wezterm.nix
    ./terminal/vim.nix
    ./terminal/helix.nix
    ./wayland/hyprland.nix
  ];

  wezterm.enable =
    lib.mkDefault true;
  hyprland.enable =
    lib.mkDefault true;
  vim.enable =
    lib.mkDefault true;
  helix.enable =
    lib.mkDefault true;
}
