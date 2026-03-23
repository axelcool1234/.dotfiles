{ lib, config, theme, ... }:
with lib;
let
  program = "zathura";
  program-module = config.modules.${program};
  zathuraThemeSource = theme.lookupAssetSource program;

  # Zathura only needs a relative include target when the selected theme is an
  # asset-backed colors file realized under the XDG config tree.
  zathuraThemeTarget = theme.matchProvider program {
    null = null;
    asset = provider: provider.target;
    default = _: null;
  };

  # Feed Zathura one relative include line through programs.zathura.extraConfig
  # only when a non-Stylix theme asset has been realized under dotfiles-theme/.
  themeIncludeLine =
    lib.optionalString
      (theme.ifNotHandledByStylix program (_: true) != null && zathuraThemeTarget != null)
      "include ../${zathuraThemeTarget}\n";
in
{
  options.modules.${program} = {
    enable = mkEnableOption "enables ${program} config";
  };
  config = mkIf program-module.enable {
    programs.${program} = {
      enable = true;
      extraConfig = themeIncludeLine;
    };
    xdg.configFile = lib.optionalAttrs (zathuraThemeSource != null && zathuraThemeTarget != null) {
      "${zathuraThemeTarget}".source = zathuraThemeSource;
    };
  };
}
