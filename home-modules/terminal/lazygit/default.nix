{ pkgs, lib, config, themes, theme, ... }:
with lib;
let
  program = "lazygit";
  program-module = config.modules.${program};
  lazygitProvider = themes.helpers.getAppProvider theme "lazygit";
  lazygitThemeSource =
    if lazygitProvider != null && lazygitProvider.type == "asset" then
      themes.helpers.resolveAssetSource lazygitProvider
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
