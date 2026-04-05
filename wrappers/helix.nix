{
  config,
  hostVars,
  wlib,
  pkgs,
  selfPkgs,
  inputs,
  lib,
  system,
  ...
}:
let
  useNoctaliaTheme = hostVars.desktop-shell == "noctalia-shell";
in
{
  imports = [ wlib.wrapperModules.helix ];

  config = {
    package = inputs.modded-helix.packages.${system}.default.override {
      includeGrammarIf = grammar: grammar.name != "bovex";
    };

    escapingFunction = wlib.escapeShellArgWithEnv;

    # In Noctalia mode, keep Helix's config root on the real ~/.config so the
    # live theme written to ~/.config/helix/themes/noctalia.toml stays visible,
    # while still using the wrapper-generated config.toml via --config.
    env.XDG_CONFIG_HOME = lib.mkIf useNoctaliaTheme (lib.mkForce ''${"$"}HOME/.config'');
    flags."--config" = lib.mkIf useNoctaliaTheme config.constructFiles.config.path;

    settings = lib.mkMerge [
      (lib.mkIf useNoctaliaTheme {
        theme = "noctalia";
      })
      {
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
          (lib.getExe pkgs.${hostVars.shell})
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
          g.k = "goto_hover"; # Jump into hover

          # Lazygit integration
          "C-g" = [
            ":sh rm -f /tmp/lazygit-path"
            ":write-all"
            ":new"
            ":insert-output env LAZYGIT_OPEN_PATH_FILE=/tmp/lazygit-path ${lib.getExe selfPkgs.lazygit}"
            ":sh printf \"\\x1b[?1049h\" > /dev/tty"
            ":buffer-close!"
            ":open %sh{cat /tmp/lazygit-path}"
            ":redraw"
            ":reload-all"
            ":set mouse false"
            ":set mouse true"
          ];

          # Scooter integration
          "C-r" = [
            ":write-all"
            ":insert-output ${lib.getExe pkgs.scooter} out> /dev/tty"
            ":redraw"
            ":reload-all"
          ];

          # Yaziao integration
          "-" = [
            ":sh rm -f /tmp/helix-yazi"
            ":insert-output ${lib.getExe selfPkgs.yazi} \"%{buffer_name}\" --chooser-file=/tmp/helix-yazi"
            ":sh printf \"\\x1b[?1049h\\x1b[?2004h\" > /dev/tty"
            ":open %sh{cat /tmp/helix-yazi}"
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
      }
    ];
  };
}
