{ config, pkgs, ... }:
let
    aliases = {
      cd = "z";
      ls = "ls --color=auto";
      ll = "ls -l";
      grep = "grep --color=auto";
      nvim = "steam-run nvim";
      nixos-switch = "sudo nixos-rebuild switch --flake $HOME/.dotfiles#default";
      home-switch = "home-manager switch --flake $HOME/.dotfiles#axelcool1234";
    };
in
{
  nixpkgs = {
    config = {
      allowUnfree = true;
      allowUnfreePredicate = (_: true);
    };
  };
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
    pkgs.hello
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

  programs = {
    # Bash Configuration
    bash = {
        enable = true;
        shellAliases = aliases; 
        bashrcExtra = ''
        PS1='\[\033[1;31m\][\[\033[1;33m\]\u\[\033[1;32m\]@\[\033[1;34m\]\h:\[\033[35m\]/\w\[\033[31m\]]\[\033[00m\]'
        eval "$(zoxide init bash)"
        '';
    };
    # Zsh Configuration
    zsh = {
        enable = true;
        shellAliases = aliases; 
        initExtra = 
        ''
        autoload -U colors && colors
        PS1="%{$fg[red]%}%n%{$reset_color%}@%{$fg[blue]%}%m %{$fg[yellow]%}%~ %{$reset_color%}%% "
        eval "$(zoxide init zsh)"
        '';
    };
    # Git Configuration
    git = {
        enable = true;
        userName = "Axel Sorenson";
        userEmail = "AxelPSorenson@gmail.com";
    };
    # Firefox Configuration
    firefox = {
        enable = true;
        policies = {
            ExtensionSettings = with builtins;
            let extension = shortId: uuid: {
                name = uuid;
                value = {
                    install_url = "https://addons.mozilla.org/en-US/firefox/downloads/latest/${shortId}/latest.xpi";
                    installation_mode = "normal_installed";
                };
            };
            in listToAttrs [
                (extension "ublock-origin" "uBlock0@raymondhill.net")
                (extension "tridactyl-vim" "tridactyl.vim@cmcaine.co.uk")
            ];
            # To add additional extensions, find it on addons.mozilla.org, find
            # the short ID in the url (like https://addons.mozilla.org/en-US/firefox/addon/!SHORT_ID!/)
            # Then, download the XPI by filling it in to the install_url template, unzip it,
            # run `jq .browser_specific_settings.gecko.id manifest.json` or
            # `jq .applications.gecko.id manifest.json` to get the UUID
            #
            # You don’t need to get the UUID from the xpi. 
            # You can install it then find the UUID in about:debugging#/runtime/this-firefox.
        };
    };
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
