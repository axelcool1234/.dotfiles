{
  wlib,
  pkgs,
  inputs,
  ...
}:
{
  imports = [ wlib.wrapperModules.helix ];

  config = {
    package = inputs.modded-helix.packages.${pkgs.stdenv.hostPlatform.system}.default.override {
      includeGrammarIf = grammar: grammar.name != "bovex";
    };

    settings = {
      theme = "ao";
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
  };
}
