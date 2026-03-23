{ pkgs, lib, config, theme, ... }:
with lib;
let
  program = "wlogout";
  program-module = config.modules.${program};
  wlogoutProvider = theme.lookupProvider program;

  # Wlogout uses either generated structured CSS, no external CSS under Stylix,
  # or one asset-backed stylesheet copied into the realized target path.
  wlogoutAssetSource = theme.matchProvider program {
    null = null;
    structured = _: null;
    asset = _: theme.requireAssetSource program;
    default = _: null;
  };
  wlogoutWrapperDir = pkgs.runCommandLocal "wlogout-config-dir" { } ''
    mkdir -p "$out/icons"
    ln -s ${./style.css} "$out/style.css"
    ln -s ${./assets/layout} "$out/layout"
    ln -s ${./assets/icons/hibernate.png} "$out/icons/hibernate.png"
    ln -s ${./assets/icons/lock.png} "$out/icons/lock.png"
    ln -s ${./assets/icons/logout.png} "$out/icons/logout.png"
    ln -s ${./assets/icons/reboot.png} "$out/icons/reboot.png"
    ln -s ${./assets/icons/shutdown.png} "$out/icons/shutdown.png"
    ln -s ${./assets/icons/suspend.png} "$out/icons/suspend.png"
  '';
  wlogoutColors = theme.lookupProviderOption wlogoutProvider "colors";
  wlogoutAccentColor = theme.lookupProviderOption wlogoutProvider "accentColor";
  wlogoutThemeText =
    if wlogoutColors != null && wlogoutAccentColor != null then
      ''
        @define-color overlay alpha(${wlogoutColors.base}, 0.7);
        @define-color text ${wlogoutColors.text};
        @define-color surface0 ${wlogoutColors.surface0};
        @define-color base ${wlogoutColors.base};
        @define-color accent ${wlogoutAccentColor};
      ''
    else
      null;
in
{
  options.modules.${program} = {
    enable = mkEnableOption "enables ${program} config";
  };

  config = mkIf program-module.enable (
    mkMerge [
      {
        programs.wlogout.enable = true;
        xdg.configFile.wlogout = mkIf (!theme.isHandledByStylix wlogoutProvider) {
          source = wlogoutWrapperDir;
        };
      }
      (lib.optionalAttrs (wlogoutAssetSource != null) {
        xdg.configFile."${wlogoutProvider.target}".source = wlogoutAssetSource;
      })
      (lib.optionalAttrs (wlogoutAssetSource == null && wlogoutThemeText != null) {
        xdg.configFile."dotfiles-theme/wlogout.css".text = wlogoutThemeText;
      })
    ]
  );
}
