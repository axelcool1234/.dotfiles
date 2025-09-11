{
  inputs,
  pkgs,
  config,
  lib,
  ...
}:
let # TODO: Everything in this `let ... in` block should be placed in seperate locations
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

  # TODO: Move this somewhere else
  home.file.".config/tree-sitter/config.json".source =
    "${lean-highlighter}/share/tree-sitter/config.json";

  home.packages = with pkgs; [
    # Shell
    fish
    nushell
    starship

    # Editor
    inputs.jump-helix.packages.${pkgs.system}.default
    helix-plugins # Plugins (mainly used for Lean right now)

    # Helix integrations
    git
    lazygit
    yazi
    scooter

    # Lang specific (Nix LSP + Lean highlighter)
    nil
    nixpkgs-fmt
    lean-highlighter

    # Terminal Utils
    zoxide
    ripgrep
    fd
    fzf
    nix-prefetch-github
    neofetch

    # Clipboard
    wl-clipboard
    cliphist
    clipboard-jh

    # Gui/Programs
    vesktop
    spicetify-cli
    stremio
    slack

    # TODO: This is here because it fixes wl-copy, making it properly copy to my system clipboard
    glib
  ];
}
