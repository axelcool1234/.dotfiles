{
  inputs,
  pkgs,
  lib,
  config,
  username,
  hostname,
  ...
}:
with lib;
let
  program = "helix";
  program-module = config.modules.${program};
in
{
  options.modules.${program} = {
    enable = mkEnableOption "enables ${program} config";
  };
  config = mkIf program-module.enable {
    programs.${program} = {
      enable = true;
      defaultEditor = true;
      package = inputs.modded-helix.packages.${pkgs.system}.default;
      extraPackages = [ pkgs.nixd ];
      settings = {
        theme = "tokyonight";
        editor = {
          scrolloff = 8;
          auto-pairs = false;
          insert-final-newline = false;
          mouse = false;
          color-modes = true;
          bufferline = "always";
          line-number = "relative";
          popup-border = "all";
          shell = [
            "nu"
            "-c"
          ];
          idle-timeout = 0;
          end-of-line-diagnostics = "disable";
          enable-focus-dimmer = true;

          inline-diagnostics = {
            cursor-line = "disable";
          };

          lsp = {
            display-messages = true;
            display-inlay-hints = true;
            display-progress-messages = true;
          };

          indent-guides.render = true;

          whitespace.render = {
            space = "none";
            tab = "all";
            nbsp = "all";
            nnbsp = "all";
            newline = "all";
          };
        };

        keys = {
          insert = {
            "C-space" = "completion";
          };

          normal = {
            # Buffer binds (test)
            H = "goto_previous_buffer"; # Move to left buffer
            L = "goto_next_buffer"; # Move to right buffer
            g.q = ":bc"; # Close buffer
            g.Q = ":bc!"; # Close buffer with unsaved changed
            g.w = "goto_word_flash"; # Better jump motion

            # Lazygit integration
            "C-g" = [
              ":write-all"
              ":insert-output lazygit out> /dev/tty"
              ":redraw"
              ":reload-all"
            ];

            # Scooter integration
            "C-r" = [
              ":write-all"
              ":insert-output scooter out> /dev/tty"
              ":redraw"
              ":reload-all"
            ];

            # Yazi integration
            "-" = [
              ":sh rm -f /tmp/unique-file"
              ":insert-output yazi %{buffer_name} --chooser-file=/tmp/unique-file"
              ":open %sh{cat /tmp/unique-file}"
              ":redraw"
            ];

            # Remaps
            x = "extend_line";
          };

          select = {
            x = "extend_line";
            g.w = "extend_to_word_flash";
          };
        };
      };
      languages = {
        language = [
          {
            name = "nix";
            auto-format = true;
          }
        ];
        language-server = {
          # nixd = {
          #   command = "nixd";
          #   args = [ "--semantic-tokens=true" ];
          #   config.nixd =
          #     let
          #       myFlake = ''(builtins.getFlake "/home/${username}/.dotfiles")''; # TODO: Figure out a safer way to point to flake!
          #       homeUser = "${username}@${hostname}";
          #       nixosOpts = ''${myFlake}.nixosConfigurations."${hostname}".options'';
          #       homeOpts = ''${myFlake}.homeConfigurations."${homeUser}".options'';
          #     in
          #     {
          #       nixpkgs.expr = "import ${myFlake}.inputs.nixpkgs { }";
          #       formatting.command = [ "${lib.getExe pkgs.nixfmt-rfc-style}" ];
          #       options = {
          #         nixos.expr = nixosOpts;
          #         home-manager.expr = homeOpts;
          #       };
          #     };
          # };
          texlab = {
            config.texlab = {
              build = {
                onSave = true;
                forwardSearchAfter = true;
                # configure tectonic as the build tool
                executable = "tectonic";
                args = [
                  "-X"
                  "compile"
                  "%f"
                  "--synctex"
                  "-Zshell-escape"
                  "--keep-logs"
                  "--keep-intermediates"
                ];
              };
              forwardSearch = {
                executable = "zathura";
                args = [
                  "--synctex-forward"
                  "%l:1:%f"
                  "%p"
                ];
              };
              chktex.onEdit = true;
            };
          };
        };
      };
    };
    # xdg.configFile.${program}.source = ./.;
  };
}
