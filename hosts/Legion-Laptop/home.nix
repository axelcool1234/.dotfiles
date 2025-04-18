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
    steam-run # See: https://github.com/wez/wezterm/issues/5879
    alacritty
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
    bat-extras.batman
    cloc
    tealdeer
    ripgrep
    nix-prefetch-github

    # Clipboard
    wl-clipboard
    cliphist
    clipboard-jh

    # Gui/Programs
    (discord.override {
    	withVencord = true;
      # withOpenASAR = true;
    })
    spicetify-cli
    slack
  ];
}
