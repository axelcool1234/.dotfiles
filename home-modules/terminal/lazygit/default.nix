{ pkgs, lib, config, theme, ... }:
with lib;
let
  program = "lazygit";
  program-module = config.modules.${program};
  lazygitThemeSource =
    let
      source = theme.resolveAssetSource "lazygit";
    in
    if source != null then
      source
    else
      throw "theme.apps.lazygit must fetch an upstream theme asset";
in
{
  options.modules.${program} = {
    enable = mkEnableOption "enables ${program} config";
  };
  config = mkIf program-module.enable {
    home.packages = [ pkgs.lazygit ];
    xdg.configFile."lazygit/config.yml".source = lazygitThemeSource;
  };
}
