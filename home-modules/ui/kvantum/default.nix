{ lib, config, theme, ... }:
with lib;
let
  program = "kvantum";
  program-module = config.modules.${program};
  kvantumThemeName = theme.ifNotHandledByStylix program (provider: theme.requireProviderOption provider "themeName");

  # Kvantum only needs a realized config target when the selected provider is
  # asset-backed and declares where its theme directory should be copied.
  kvantumThemeTarget = theme.matchProvider program {
    null = null;
    asset = provider: provider.target;
    default = _: null;
  };
  kvantumAssetSource =
    theme.ifNotHandledByStylix program theme.lookupAssetSource;
in
{
  options.modules.${program} = {
    enable = mkEnableOption "enables ${program} UI config";
  };

  config = mkIf program-module.enable (
    mkMerge [
      {
        xdg.configFile."Kvantum/kvantum.kvconfig" = mkIf (kvantumThemeName != null) {
          text = ''
            [General]
            theme=${kvantumThemeName}
          '';
        };
      }
      (lib.optionalAttrs (kvantumAssetSource != null && kvantumThemeTarget != null) {
        xdg.configFile."${kvantumThemeTarget}".source = kvantumAssetSource;
      })
    ]
  );
}
