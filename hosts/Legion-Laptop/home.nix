{ config, pkgs, ... }:
let
    aliases = {
      cd = "z";
      cat = "bat --color=always";
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
  home.packages = with pkgs; [
    # Theme/Fonts
    (nerdfonts.override { fonts = [ "JetBrainsMono" ]; })

    # Terminal
    wezterm
    helix
    neofetch    
    lazygit
    bat
    zoxide
    fzf
    tldr
    btop
    procs
    cloc
    ncspot
    steam-run

    # Gui/Programs
    # firefox
    discord
    spotify
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
    EDITOR = "helix";
  };

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
    # Fish Configuration
    fish = {
      enable = true;
      shellAliases = aliases;
      shellInit = ''
        zoxide init fish | source
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
                (extension "tokyo-night-v3" "{6c8ef7a0-0691-4323-8bdc-af24f54985ec}")
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
    # Helix Configuration
    helix = {
      enable = true;
      settings = {
        theme = "tokyonight";
        editor = {
          line-number = "relative";
          bufferline = "always";
          lsp.display-messages = true;

          mouse = false;
          auto-pairs = false;
          color-modes = true;

          indent-guides = {
            render = true;
          };
       };  
       keys = {
         normal = {
           up = "no_op";
           down = "no_op";
           left = "no_op";
           right = "no_op";
         };

         insert = {
           up = "no_op";
           down = "no_op";
           left = "no_op";
           right = "no_op";
         };
       };
     };
    };
    # Zellij Configuration
    zellij = {
      enable = true;
      settings = {
        theme = "tokyo-night";
      };
    };
  };

    # Wayland Configuration
    wayland = {
      windowManager.hyprland = {
        enable = true;
        settings = {
          "$mod" = "SUPER";
          "$terminal" = "wezterm";
          # monitor="DP-1,2560x1600@165,0x0,1";
          monitor=",highres,auto,1";
          misc = {
            disable_hyprland_logo = true;
            disable_splash_rendering = true;
          };
          bind =
            [
              "$mod, F, exec, firefox"
              "$mod, D, exec, discord"
              "$mod, Q, exec, $terminal"
              "$mod, C, killactive"
              "$mod, M, exit"
              "$mod, V, togglefloating"
              "$mod, P, pseudo" # dwindle
              "$mod, J, togglesplit" # dwindle
            ]
            ++ (
              # workspaces
              # binds $mod + [shift +] {1..10} to [move to] workspace {1..10}
              builtins.concatLists (builtins.genList (
                  x: let
                    ws = let
                      c = (x + 1) / 10;
                    in
                      builtins.toString (x + 1 - (c * 10));
                  in [
                    "$mod, ${ws}, workspace, ${toString (x + 1)}"
                    "$mod SHIFT, ${ws}, movetoworkspace, ${toString (x + 1)}"
                  ]
                )
                10)
            );
        };
      };
    };
  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
