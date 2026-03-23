{
  pkgs,
  lib,
  config,
  hostname,
  desktop,
  theme,
  ...
}:
with lib;
let
  program = "waybar";
  program-module = config.modules.${program};

  # Waybar either copies one asset-backed stylesheet target or generates the
  # shared color-variable layer inline for structured providers.
  waybarAssetTarget = theme.matchProvider program {
    null = null;
    asset = provider: provider.target;
    default = _: null;
  };
  waybarAssetSource = theme.lookupAssetSource program;
  themeFonts = theme.requireThemeData "fonts";
  waybarColors = theme.requireProviderOption program "colors";
  renderCssColorVariables = colors:
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: value: "@define-color ${name} ${value};") colors
    );
  waybarThemeText =
    renderCssColorVariables waybarColors
    + "\n"
    + ''
      * {
        font-family: "${themeFonts.terminal.family}", "${themeFonts.symbols.name}";
        font-size: ${toString themeFonts.ui.size}pt;
      }

      #workspaces,
      #workspaces button,
      #workspaces button label,
      #workspaces button image,
      #workspaces button * {
        font-family: "${themeFonts.ui.name}", "${themeFonts.symbols.name}";
      }
    '';
in
{
  options.modules.${program} = {
    enable = mkEnableOption "enables ${program} config";
  };

  config = mkIf program-module.enable (
    mkMerge [
      {
        programs.waybar = {
          enable = true;
          style = builtins.readFile ./style.css;
          settings =
            # TODO: There should be `if desktop == "hyprland"` checks inside `settings.nix`, not here.
            # That way most of the settings can be shared between hyprland and other desktops.
            if desktop == "hyprland" then
              import ./settings.nix { inherit hostname waybarColors; }
            else
              [ ];
        };
      }
      (lib.optionalAttrs (waybarAssetSource != null) {
        xdg.configFile."${waybarAssetTarget}".source = waybarAssetSource;
      })
      (lib.optionalAttrs (waybarAssetSource == null) {
        xdg.configFile."dotfiles-theme/waybar.css".text = waybarThemeText;
      })
    ]
  );
}
