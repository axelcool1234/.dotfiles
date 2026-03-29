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

  package = selfPkgs.shell;

  runtimeInputs = [
    # GUI
    selfPkgs.zathura # PDFs
    pkgs.imv     # Images
    pkgs.mpv     # Videos

    # Utils
    selfPkgs.editor  # Edit text within files
    pkgs.ripgrep     # Search text within files
    pkgs.fd          # Search files themselves
    pkgs.fzf         # Fuzzy finder
    selfPkgs.git     # Version control
    selfPkgs.harness # Default LLM harness
    selfPkgs.neovim  # Secondary editor 
    selfPkgs.yazi    # Terminal file manager

    # Info
    selfPkgs.btop  # Machine health information
    pkgs.fastfetch # Machine specs

    # Nix
    inputs.nix-index-database.packages.${system}.nix-index-with-db # nix-locate
    inputs.nix-index-database.packages.${system}.comma-with-db     # ,
    pkgs.nh                                                        # (nh) replacement for nix os build/switch
    pkgs.nix-init                                                  # helper CLI for generating Nix package expressions from upstream source projects.
    pkgs.nix-output-monitor                                        # (nom) replacement for nix build
    pkgs.nix-tree                                                  # browse dependency graphs of nix derivations
    pkgs.nix-prefetch                                              # get hashes
  ];

  env = {
    VISUAL = "${lib.getExe selfPkgs.editor}"; # Default editor
    EDITOR = "${lib.getExe selfPkgs.editor}"; # Default editor
  };
}
