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
in
{
  options.modules.${program} = {
    enable = mkEnableOption "enables ${program} config";
  };

  config = mkIf program-module.enable {
    home.packages = [
      inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.code
    ];

    home.file.".code/config.toml".source = tomlFormat.generate "code-config.toml" {
      tui.theme = {
        name = "custom";
        colors = {
          primary = theme.hex "blue";
          secondary = theme.hex "green";
          background = theme.hex "base";
          foreground = theme.hex "text";
          border = theme.hex "surface1";
          border_focused = theme.hex "overlay0";
          selection = theme.hex "surface0";
          cursor = theme.hex "rosewater";
          success = theme.hex "green";
          warning = theme.hex "yellow";
          error = theme.hex "red";
          info = theme.hex "sky";
          text = theme.hex "text";
          text_dim = theme.hex "subtext0";
          text_bright = theme.hex "rosewater";
          keyword = theme.hex "mauve";
          string = theme.hex "green";
          comment = theme.hex "overlay1";
          function = theme.hex "blue";
          spinner = theme.hex "sapphire";
          progress = theme.hex "blue";
        };
      };
    };
  };
}
