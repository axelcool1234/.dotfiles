{
  inputs,
  lib,
  pkgs,
  self,
  system,
  wlib,
  ...
}:
let
  useNoctaliaTheme = self.defaults.desktop-shell == "noctalia-shell";
in
{
  imports = [ wlib.modules.default ];

  config = {
    package = inputs.llm-agents.packages.${system}.code;

    # Every Code stores project trust and other mutable state in ~/.code/
    # alongside theme config. Merge only the generated [tui.theme] section into
    # the live config before launch instead of replacing the whole file.
    runShell = lib.optionals useNoctaliaTheme [
      ''
        config_path="$HOME/.code/config.toml"
        theme_fragment_path="$HOME/.cache/noctalia/every-code-theme.toml"
        if [ -f "$theme_fragment_path" ]; then
          tmp_path="$(mktemp)"
          mkdir -p "$(dirname "$config_path")"
          trap 'rm -f "$tmp_path"' EXIT

          if [ -f "$config_path" ]; then
            ${pkgs.gawk}/bin/awk '
              BEGIN {
                skip = 0
              }

              /^\[tui\.theme(\..*)?\]$/ {
                skip = 1
                next
              }

              /^\[/ {
                if (skip && $0 !~ /^\[tui\.theme(\..*)?\]$/) {
                  skip = 0
                }
              }

              !skip {
                print
              }
            ' "$config_path" > "$tmp_path"
          else
            : > "$tmp_path"
          fi

          if [ -s "$tmp_path" ]; then
            printf '\n' >> "$tmp_path"
          fi

          cat "$theme_fragment_path" >> "$tmp_path"
          mv "$tmp_path" "$config_path"
        fi
      ''
    ];
  };
}
