{
  pkgs,
  inputs,
  lib,
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
    glide-browser.enable = true;

    # LLM CLI
    code.enable = true;

    # PDF Viewer
    zathura.enable = true;

    # Music player
    spicetify.enable = true;

    # Desktop UI
    waybar.enable = true;
    rofi.enable = true;
    dunst.enable = true;
    wlogout.enable = true;
    gtk.enable = true;
    kvantum.enable = true;
    avizo.enable = true;
    imv.enable = true;
    mpv.enable = true;
    swappy.enable = true;
    thunar.enable = true;
    wpaperd.enable = true;

    # Desktop configuration
    hyprland.enable = true; # This configures the Hyprland session and desktop integrations

    # Messenger (Discord)
    nixcord.enable = true;

    # Nix tools
    # - nh
    # - nix-index-database
    # - comma (replacement for nix-shell -p)
    # - direnv with lorri background builds
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

    # LLM CLIs
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.codex

    # Scripts
    (callPackage ./pkgs/ns.nix { })
    (callPackage ./pkgs/ts.nix { ns = callPackage ./pkgs/ns.nix { }; })
    (callPackage ./pkgs/restart-waybar.nix { })

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
