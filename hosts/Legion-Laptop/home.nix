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
      lean4
    ]
  );
  helix-plugins = pkgs.writeShellScriptBin "shx" ''
    export PATH=$PATH:${binPath}
    exec ${inputs.steel-helix.packages.${pkgs.system}.default}/bin/hx "$@"
  '';
  lean-highlighter = (pkgs.callPackage ../../pkgs/lean-highlighter { });
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

  home.file.".config/tree-sitter/config.json".source =
    "${lean-highlighter}/share/tree-sitter/config.json";

  home.packages = with pkgs; [
    # Development Essentials
    fish
    nushell
    starship
    helix
    helix-plugins # Plugins (mainly used for Lean right now)
    lean-highlighter
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

    # TODO: This is here because it fixes wl-copy, making it properly copy to my system clipboard
    glib
  ];
}
