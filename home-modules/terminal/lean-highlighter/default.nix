{
  pkgs,
  lib,
  config,
  ...
}:
with lib;
let
  module = "lean-highlighter";
  leanHighlighter = pkgs.callPackage ../../../pkgs/lean-highlighter { };
in
{
  options.modules.${module} = {
    enable = mkEnableOption "enables ${module}";
  };

  config = mkIf config.modules.${module}.enable {
    home.packages = [ leanHighlighter ];

    xdg.configFile."tree-sitter/config.json".source =
      "${leanHighlighter}/share/tree-sitter/config.json";
  };
}

