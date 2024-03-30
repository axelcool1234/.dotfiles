{ pkgs, lib, ... }: {
  imports = [
    ./wayland/hyprland.nix
    ./terminal/wezterm.nix
    ./terminal/shell.nix
    ./terminal/vim.nix
    ./terminal/helix.nix
    ./terminal/git.nix
    ./programs/firefox.nix
    ./programs/vencord.nix
    ./programs/spicetify.nix
  ];

  hyprland.enable =
    lib.mkDefault true;
  wezterm.enable =
    lib.mkDefault true;

  fish.enable =
    lib.mkDefault true;
  zsh.enable =
    lib.mkDefault true;
  bash.enable =
    lib.mkDefault true;
    
  vim.enable =
    lib.mkDefault true;
  helix.enable =
    lib.mkDefault true;
  git.enable =
    lib.mkDefault true;
  
  firefox.enable = 
    lib.mkDefault true;
  vencord.enable =
    lib.mkDefault true;
  spicetify.enable =
    lib.mkDefault true;
}
