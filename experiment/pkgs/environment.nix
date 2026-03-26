{
  inputs,
  lib,
  pkgs,
  system,
  selfPkgs,
  ...
}:
inputs.wrappers.lib.wrapPackage {
  inherit pkgs;

  package = selfPkgs.fish;

  runtimeInputs = [
    # GUI
    pkgs.slack         # Work
    selfPkgs.browser   # Default browser
    selfPkgs.spicetify # Music
    pkgs.zathura       # PDFs
    pkgs.imv           # Images
    pkgs.mpv           # Videos

    # Utils
    pkgs.ripgrep # Search text within files
    pkgs.fd      # Search files themselves
    pkgs.fzf     # Fuzzy finder
    selfPkgs.git # Version control

    # Info
    pkgs.btop      # Machine health information
    pkgs.fastfetch # Machine specs

    # Nix
    inputs.nix-index-database.packages.${system}.nix-index-with-db
    inputs.nix-index-database.packages.${system}.comma-with-db
    pkgs.nh # (nh) replacement for nix os build/switch
    pkgs.nix-init
    pkgs.nix-output-monitor # (nom) replacement for nix build
    pkgs.nix-tree # browse dependency graphs of nix derivations
    pkgs.nix-prefetch # get hashes

    # Misc
    selfPkgs.harness # Default LLM harness
  ];

  env = {
    EDITOR = "${lib.getExe selfPkgs.editor}"; # Default browser
  };
}
