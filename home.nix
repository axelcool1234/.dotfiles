{
  inputs,
  pkgs,
  config,
  lib,
  ...
}:
{
  # Allows home-manager to manage unfree packages
  nixpkgs = {
    config = {
      allowUnfree = true;
      allowUnfreePredicate = (_: true);
    };
  };

  home.username = "axelcool1234";
  home.homeDirectory = "/home/axelcool1234";
  home.stateVersion = "23.11"; # Please read https://home-manager-options.extranix.com/?query=home.stateVersion before changing.
  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    # Shell
    fish # Enabled because scripts for my desktop require them
    nushell
    starship

    # Editor
    inputs.jump-helix.packages.${pkgs.system}.default

    # Helix integrations
    git
    lazygit
    yazi
    scooter

    # Terminal Utils
    zoxide
    ripgrep
    fd
    fzf
    neofetch

    # Gui/Programs
    spicetify-cli
    stremio
    slack

    # --- Lang specific --- #
    # Nix
    nil # LSP
    nixpkgs-fmt # Formatter
    nix-prefetch-github
    # Hyprlang
    hyprls
  ];
}
