{
  pkgs,
  lib,
  config,
  desktop,
  hostname,
  theme ? null,
  ...
}:
with lib;
let
  program = "hyprland"; # Technically not a program here
  program-module = config.modules.${program};
in
{
  options.modules.${program} = {
    enable = mkEnableOption "enables ${program} config";
  };
  config = mkIf (program-module.enable && desktop == "hyprland") (
    let
      inherit (theme) requireThemeData;

      themeFonts = requireThemeData "fonts";
      hyprlandThemeSource = theme.lookupAssetSource "hyprland";
      hyprlandColors = theme.lookupProviderOption "hyprland" "colors";
      gtkThemeName = theme.lookupProviderOption "gtk" "themeName";
      cursorName = theme.lookupProviderOption "cursor" "name";
      hyprlandThemeText =
        if hyprlandColors != null then
          lib.concatStringsSep "\n\n" (
            lib.mapAttrsToList (name: value: ''
              ${"$" + name} = rgb(${lib.removePrefix "#" value})
              ${"$" + name}Alpha = ${lib.removePrefix "#" value}
            '') hyprlandColors
          )
        else
          null;
      hyprlandThemeEnv = lib.concatStrings (
        lib.optional (gtkThemeName != null) "env = GTK_THEME,${gtkThemeName}\n"
        ++ lib.optional (cursorName != null) "env = XCURSOR_THEME,${cursorName}\n"
        ++ lib.optional (cursorName != null) "env = HYPRCURSOR_THEME,${cursorName}\n"
      );
      legionMonitorOverride = lib.optionalString (hostname == "legion") ''
        # Legion internal panel override.
        #
        # This laptop's built-in display is `eDP-1` at 2560x1600 and supports
        # 165 Hz. During validation of the `nvidia-only` boot path, Hyprland came
        # up at 60 Hz even though 165 Hz was available, so we pin the preferred
        # internal-panel mode explicitly for this host.
        monitor=eDP-1,2560x1600@165,0x0,1.6
      '';

      hyprConfigDir = pkgs.runCommandLocal "hypr-config-dir" { } ''
        mkdir -p "$out"
        cp ${./hypridle.conf} "$out/hypridle.conf"
        cp ${./hyprland.conf} "$out/hyprland.conf"
        cp ${./hyprlock.conf} "$out/hyprlock.conf"
        cp ${./hyprpaper.conf} "$out/hyprpaper.conf"
        cp ${./pyprland.toml} "$out/pyprland.toml"
        chmod -R u+w "$out"
        substituteInPlace "$out/hyprlock.conf" \
          --replace-fail '__HYPRLOCK_FONT__' '${themeFonts.lock.name}' \
          --replace-fail '__HYPRLOCK_CLOCK_SIZE__' '${toString themeFonts.lock.clockSize}' \
          --replace-fail '__HYPRLOCK_DATE_SIZE__' '${toString themeFonts.lock.dateSize}' \
          --replace-fail '__HYPRLOCK_INPUT_SIZE__' '${toString themeFonts.lock.inputSize}'
        cat >> "$out/hyprland.conf" <<'EOF'

${legionMonitorOverride}
EOF
      '';
    in
    mkMerge [
    {
      xdg.configFile = {
        hypr = {
          source = hyprConfigDir;
          recursive = true;
        };
        "dotfiles-theme/hyprland-session.conf".text = hyprlandThemeEnv;
      }
      // lib.optionalAttrs (hyprlandThemeText != null) {
        "dotfiles-theme/hyprland.conf".text = hyprlandThemeText;
      }
      // lib.optionalAttrs (hyprlandThemeText == null && hyprlandThemeSource != null) {
        "dotfiles-theme/hyprland.conf".source = hyprlandThemeSource;
      };
      home.file.".face".source = ./.face;
    }
  ]);
}
