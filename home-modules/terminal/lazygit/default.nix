{ pkgs, lib, config, theme, ... }:
with lib;
let
  program = "lazygit";
  program-module = config.modules.${program};
  lazygitProvider = theme.providerFor program;
  lazygitThemeSource =
    let
      source = theme.resolveAssetSource lazygitProvider;
    in
    if source != null then
      source
    else if theme.isHandledByStylix lazygitProvider then
      null
    else
      throw "theme.apps.lazygit must fetch an upstream theme asset";
in
{
  options.modules.${program} = {
    enable = mkEnableOption "enables ${program} config";
  };
  config = mkIf program-module.enable {
    home.packages = [ pkgs.lazygit ];
    xdg.configFile = lib.optionalAttrs (lazygitThemeSource != null) {
      "lazygit/config.yml".source = lazygitThemeSource;
    };
  };
}
