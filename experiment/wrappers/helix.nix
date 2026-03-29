{
  config,
  wlib,
  pkgs,
  selfPkgs,
  inputs,
  lib,
  self,
  system,
  ...
}:
let
  useNoctaliaTheme = self.defaults.desktop-shell == "noctalia-shell";
in
{
  imports = [ wlib.wrapperModules.helix ];

  config = {
    package = inputs.modded-helix.packages.${system}.default.override {
      includeGrammarIf = grammar: grammar.name != "bovex";
    };

    escapingFunction = wlib.escapeShellArgWithEnv;

    runShell = lib.optionals useNoctaliaTheme [
      ''
        runtime_base="${"$"}{XDG_RUNTIME_DIR:-${"$"}{XDG_CACHE_HOME:-${"$"}HOME/.cache}}"
        export XDG_CONFIG_HOME="$(mktemp -d "$runtime_base/helix-wrapper.XXXXXX")"
      ''
      ''mkdir -p "$XDG_CONFIG_HOME/helix"''
      ''cp ${config.generatedConfig.placeholder}/helix/config.toml "$XDG_CONFIG_HOME/helix/config.toml"''
      ''if [ -f ${config.generatedConfig.placeholder}/helix/languages.toml ]; then cp ${config.generatedConfig.placeholder}/helix/languages.toml "$XDG_CONFIG_HOME/helix/languages.toml"; fi''
      ''if [ -f ${config.generatedConfig.placeholder}/helix/ignore ]; then cp ${config.generatedConfig.placeholder}/helix/ignore "$XDG_CONFIG_HOME/helix/ignore"; fi''
      ''if [ -e "${"$"}HOME/.config/helix/themes" ]; then ln -sfn "${"$"}HOME/.config/helix/themes" "$XDG_CONFIG_HOME/helix/themes"; else mkdir -p "$XDG_CONFIG_HOME/helix/themes"; fi''
    ];

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
          g.k = "goto_hover"; # Jump into hover

          # Lazygit integration
          "C-g" = [
            ":write-all"
            ":insert-output ${lib.getExe pkgs.lazygit} out> /dev/tty"
            ":redraw"
            ":reload-all"
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
            ":sh rm -f /tmp/unique-file"
            ":insert-output ${lib.getExe selfPkgs.yazi} %{buffer_name} --chooser-file=/tmp/unique-file"
            ":open %sh{cat /tmp/unique-file}"
            ":redraw"
          ];

          # For noctalia theming
          "space".c = ":config-reload";

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
