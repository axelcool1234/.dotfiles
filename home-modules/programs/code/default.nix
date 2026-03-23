{
  inputs,
  pkgs,
  lib,
  config,
  theme,
  ...
}:
with lib;
let
  program = "code";
  program-module = config.modules.${program};
  tomlFormat = pkgs.formats.toml { };
  codeProvider = theme.providerFor program;
  codeColors =
    if codeProvider != null && codeProvider.type == "template" && codeProvider.options ? colors then
      codeProvider.options.colors
    else if theme.isHandledByStylix codeProvider then
      null
    else
      throw "theme.apps.code.provider.options.colors is required";
  # Code keeps user-specific state in ~/.code/config.toml, so we manage only the
  # [tui.theme] fragment and merge it during activation instead of replacing the file.
  codeThemeFragment =
    if codeColors != null then
      tomlFormat.generate "code-theme.toml" {
        tui.theme = {
          name = "custom";
          colors = codeColors;
        };
      }
    else
      null;
in
{
  options.modules.${program} = {
    enable = mkEnableOption "enables ${program} config";
  };

  config = mkIf program-module.enable {
    home.packages = [
      inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.code
    ];

    home.activation = lib.optionalAttrs (codeThemeFragment != null) {
      codeTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        config_path="$HOME/.code/config.toml"
        theme_fragment_path="${codeThemeFragment}"
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
      '';
    };
  };
}
