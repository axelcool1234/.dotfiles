{ config, pkgs, ... }:
{
  nixpkgs = {
    config = {
      allowUnfree = true;
      allowUnfreePredicate = (_: true);
    };
  };
  home.username = "axelcool1234";
  home.homeDirectory = "/home/axelcool1234";
  home.stateVersion = "23.11"; # Please read the comment before changing.
  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    # Theme/Fonts
    (nerdfonts.override { fonts = [ "JetBrainsMono" ]; })

    # Terminal
    wezterm
    helix
    neofetch    
    lazygit
    bat
    zoxide
    fzf
    tldr
    btop
    procs
    cloc
    ncspot
    steam-run

    # Gui/Programs
    # firefox
    discord
    spotify
  ];
}
