{ pkgs, lib, config, theme, ... }:
with lib;
let
  program = "lazygit";
  program-module = config.modules.${program};

  # LazyGit either consumes one upstream YAML theme asset or no explicit theme
  # settings at all when the selected theme is handled by Stylix.
  lazygitThemeSettings = theme.matchProvider program {
    null = { };
    asset = _:
      lib.importJSON (
        pkgs.runCommandLocal "lazygit-theme.json"
          {
            nativeBuildInputs = [ pkgs.remarshal ];
          }
          ''
            remarshal -if yaml -of json ${theme.requireAssetSource program} > "$out"
          ''
      );
    default = _: throw "theme.apps.lazygit must fetch an upstream theme asset";
  };
in
{
  options.modules.${program} = {
    enable = mkEnableOption "enables ${program} config";
  };
  config = mkIf program-module.enable {
    programs.${program} = {
      enable = true;
      settings = lazygitThemeSettings;
    };
  };
}
