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

    # ags
    # Terminal
    wezterm
    helix
    neofetch    
    lazygit
    bat
    zoxide
    fzf
    ranger
    tealdeer
    btop
    procs
    cloc
    ncspot
    steam-run
    fish
    starship
    git
    wget
    curl
    nix-prefetch-github

    # Clipboard
    wl-clipboard
    cliphist
    clipboard-jh

    # Gui/Programs
    (discord.override {
    	withVencord = true;
    })
    spicetify-cli
  ];
}
