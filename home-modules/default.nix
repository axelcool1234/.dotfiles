{ pkgs, lib, ... }: {
  imports = [
    ./hyprland-desktop
    ./terminal/wezterm.nix
    ./terminal/shell.nix
    ./terminal/bat.nix
    ./terminal/bottom.nix
    ./terminal/btop.nix
    ./terminal/neofetch.nix
    ./terminal/tealdeer.nix
    ./terminal/fish.nix
    ./terminal/vim.nix
    ./terminal/helix.nix
    ./terminal/git.nix
    ./terminal/lazygit.nix
    ./programs/firefox.nix
    ./programs/vencord.nix
    ./programs/spicetify.nix
    ./programs/zathura.nix
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
  lazygit.enable =
    lib.mkDefault true;
  bat.enable =
    lib.mkDefault true;
  bottom.enable =
    lib.mkDefault true;
  btop.enable =
    lib.mkDefault true;
  tealdeer.enable =
    lib.mkDefault true;
  neofetch.enable =
    lib.mkDefault true;
  zathura.enable =
    lib.mkDefault true;
  
  firefox.enable = 
    lib.mkDefault true;
  vencord.enable =
    lib.mkDefault true;
  spicetify.enable =
    lib.mkDefault true;
}
