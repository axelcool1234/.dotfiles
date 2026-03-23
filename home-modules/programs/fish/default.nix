{ pkgs, lib, config, theme, ... }:
with lib;
let
  program = "fish";
  program-module = config.modules.${program};
  fishThemeSource = theme.lookupAssetSource program;
  fishThemeScript =
    if fishThemeSource != null then
      pkgs.runCommandLocal "dotfiles-fish-theme.fish" { } ''
        # Normalize the upstream Fish theme file into a tiny script we can safely source:
        # drop comments/blank lines, treat the first token as the variable name, and
        # rewrite the remainder as one explicit `set -g NAME "value"` assignment.
        # Each NAME is a color along with its value.
        awk '
          /^#/ { next }
          /^$/ { next }
          {
            key = $1
            $1 = ""
            sub(/^ /, "", $0)
            gsub(/"/, "\\\"", $0)
            printf("set -g %s \"%s\"\n", key, $0)
          }
        ' ${fishThemeSource} > "$out"
      ''
    else
      null;
in
{
  options.modules.${program} = {
    enable = mkEnableOption "enables ${program} config";
  };
  config = mkIf program-module.enable {
    programs.${program}.enable = true;
    xdg.configFile = {
      ${program} = {
        source = ./.;
        recursive = true;
      };
    } // lib.optionalAttrs (fishThemeScript != null) {
      "dotfiles-theme/fish.fish".source = fishThemeScript;
    };
  };
}
