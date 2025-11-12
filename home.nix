{
  config,
  lib,
  inputs,
  pkgs,
  ...
}:

{
  imports = [ home-modules/default.nix ];
  config.modules = {
    # Editor
    helix.enable = true;

    # Terminal
    kitty.enable = true;

    # Shell
    nushell.enable = true;
    starship.enable = true;

    # System diagnostics
    btop.enable = true;

    # Enabled because scripts for my desktop require them
    fish.enable = true;

    # Git
    git.enable = true;
    lazygit.enable = true;

    # Browser
    firefox.enable = true;

    # PDF Viewer
    zathura.enable = true;

    # Music player
    spicetify.enable = true;

    # Desktop configuration
    hyprland.enable = true; # This configures a lot of the Hyprland services (like waybar and dunst)
  };
  config.home.packages = with pkgs; [
    # Helix integrations
    yazi
    scooter

    # Terminal Utils
    zoxide
    ripgrep
    fd
    fzf

    # Gui/Programs
    stremio
    slack

    # --- programming language specific --- #
    # Nix
    nil # LSP
    nixpkgs-fmt # Formatter
    nix-prefetch-github
    # Hyprlang
    hyprls
  ];
}
