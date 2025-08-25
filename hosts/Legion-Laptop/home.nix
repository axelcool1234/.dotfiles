{
  inputs,
  pkgs,
  config,
  lib,
  ...
}:
let
  binPath = lib.makeBinPath (
    with pkgs;
    [
      inputs.steel.packages.${system}.default
    ]
  );
  helix-plugins = pkgs.writeShellScriptBin "shx" ''
    export PATH=$PATH:${binPath}
    exec ${inputs.steel-helix.packages.${pkgs.system}.default}/bin/hx "$@"
  '';
in
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
    fish
    nushell
    starship
    helix
    helix-plugins # Plugins (mainly used for Lean right now)
    git
    lazygit
    yazi
    scooter
    zoxide
    fd
    fzf
    zip
    unzip

    # Emergency Purposes
    alacritty

    # Nix LSP
    nil
    nixpkgs-fmt

    # Hypr LSP
    hyprls

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
    # (discord.override {
    # 	withVencord = true;
    #   # withOpenASAR = true;
    # })
    vesktop
    spicetify-cli
    stremio
    slack
  ];
}
