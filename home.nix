{
  pkgs,
  inputs,
  ...
}:
{
  imports = [ home-modules/default.nix ];
  config = {
    modules = {
    # Editor (plus integrations)
    helix.enable = true;
    yazi.enable = true;

    # For Lean
    neovim.enable = true;
    lean-highlighter.enable = true;

    # Terminal
    kitty.enable = true;

    # Shell
    nushell.enable = true;
    starship.enable = true;
    zoxide.enable = true;
    ripgrep.enable = true;
    fd.enable = true;
    fzf.enable = true;
    fastfetch.enable = true;

    # System diagnostics
    btop.enable = true;

    # Enabled because scripts for my desktop require them
    fish.enable = true;

    # Git
    git.enable = true;
    lazygit.enable = true;
    jujutsu.enable = true;

    # Browser
    firefox.enable = true;
    glide-browser.enable = true;

    # LLM CLI
    code.enable = true;

    # PDF Viewer
    zathura.enable = true;

    # Music player
    spicetify.enable = true;

    # Desktop configuration
    hyprland.enable = true; # This configures a lot of the Hyprland services (like waybar and dunst)

    # Messenger (Discord)
    nixcord.enable = true;

    # Nix tools
    # - nh
    # - nix-index-database
    # - comma (replacement for nix-shell -p)
    # - direnv and nix-direnv (TODO: replace nix-direnv with alternative)
    # - nix-init
    nix-tools.enable = true;
    };
    home.packages = with pkgs; [
    # JJ
    jjui

    # Helix integrations
    scooter

    # Gui/Programs
    slack
    (callPackage ./pkgs/restart-waybar.nix { })

    # LLM CLIs
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.codex

    # --- programming language specific --- #
    # Nix
    nix-prefetch # get hashes
    nix-output-monitor # (nom) replacement for nix build
    dix # Diff Nix
    nix-tree # browse dependency graphs of nix derivations
    # Hyprlang
    hyprls
    ];
  };
}
