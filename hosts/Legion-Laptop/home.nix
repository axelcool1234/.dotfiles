{ pkgs, ... }:
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
    # Development Essentials
    wezterm
    fish
    starship
    helix
    git
    lazygit
    zoxide
    fd
    fzf
    zip
    unzip

    # Nix LSP
    nil
    nixpkgs-fmt

    # Lua LSP
    lua-language-server

    # Terminal Utils
    neofetch    
    bat
    cloc
    tealdeer
    ripgrep
    nix-prefetch-github

    # Clipboard
    wl-clipboard
    cliphist
    clipboard-jh

    # Theme/Fonts
    (nerdfonts.override { fonts = [ "JetBrainsMono" ]; })

    # Gui/Programs
    # (discord.override {
    # 	withVencord = true;
    #     # withOpenASAR = true;
    # })
    discord
    spicetify-cli
    slack
  ];
}
