{ config, pkgs, ... }:
let
    aliases = {
      ls = "ls --color=auto";
      ll = "ls -l";
      grep = "grep --color=auto";
      nvim = "steam-run nvim";
    };
in
{
  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = "axelcool1234";
  home.homeDirectory = "/home/axelcool1234";

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "23.11"; # Please read the comment before changing.

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = [
    # # Adds the 'hello' command to your environment. It prints a friendly
    # # "Hello, world!" when run.
    pkgs.hello

    # # It is sometimes useful to fine-tune packages, for example, by applying
    # # overrides. You can do that directly here, just don't forget the
    # # parentheses. Maybe you want to install Nerd Fonts with a limited number of
    # # fonts?
    (pkgs.nerdfonts.override { fonts = [ "FantasqueSansMono" ]; })

    # # You can also create simple shell scripts directly inside your
    # # configuration. For example, this adds a command 'my-hello' to your
    # # environment:
    (pkgs.writeShellScriptBin "my-hello" ''
      echo "Hello, ${config.home.username}!"
    '')
  ];

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;

    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
  };

  # Home Manager can also manage your environment variables through
  # 'home.sessionVariables'. If you don't want to manage your shell through Home
  # Manager then you have to manually source 'hm-session-vars.sh' located at
  # either
  #
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  ~/.local/state/nix/profiles/profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  /etc/profiles/per-user/axelcool1234/etc/profile.d/hm-session-vars.sh
  #
  home.sessionVariables = {
    # EDITOR = "nvim";
  };

  # Non-Nix Configs
  xdg.configFile.nvim.source = ./nvim;

  # Bash Configuration
  programs.bash = {
    enable = true;
    shellAliases = aliases; 
    bashrcExtra = ''
      PS1='\[\033[1;31m\][\[\033[1;33m\]\u\[\033[1;32m\]@\[\033[1;34m\]\h:\[\033[35m\]/\w\[\033[31m\]]\[\033[00m\]'
    '';
  };

  # Zsh Configuration
  programs.zsh = {
    enable = true;
    shellAliases = aliases; 
    initExtra = 
    ''
    autoload -U colors && colors
    PS1="%{$fg[red]%}%n%{$reset_color%}@%{$fg[blue]%}%m %{$fg[yellow]%}%~ %{$reset_color%}%% "
    '';
  };

  # Firefox Configuration
  /*
  programs.firefox = {
    enable = true;
    languagePacks = [ "en-US" ];
   ExtensionSettings = {
    "*".installation_mode = "blocked"; # blocks all addons except the ones specified below
    # uBlock Origin:
    "uBlock0@raymondhill.net" = {
      install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
      installation_mode = "force_installed";
    };
   };
  };
  */

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
