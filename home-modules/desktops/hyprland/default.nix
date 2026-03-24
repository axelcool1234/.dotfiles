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
      hyprlandHostLayout =
        if hostname == "legion" then
          ''
            # Legion monitor and workspace layout.
            #
            # This machine is treated as a single-display laptop setup. The built-in
            # panel is `eDP-1` at 2560x1600 and supports 165 Hz, so we pin that mode
            # explicitly instead of relying on compositor auto-selection.
            monitor=eDP-1,2560x1600@165,0x0,1.6

            # Bind the primary workspaces to the only active monitor on this host.
            workspace=1,monitor:eDP-1
            workspace=2,monitor:eDP-1
            workspace=3,monitor:eDP-1
            workspace=4,monitor:eDP-1
            workspace=5,monitor:eDP-1
            workspace=6,monitor:eDP-1
            workspace=7,monitor:eDP-1
            workspace=8,monitor:eDP-1
            workspace=9,monitor:eDP-1
            workspace=10,monitor:eDP-1
          ''
        else if hostname == "fermi" then
          ''
            # Fermi monitor and workspace layout.
            #
            # This host is the desk setup with three external monitors:
            # - `DP-3`: Lenovo display on the left
            # - `DP-4`: ASUS display in the center
            # - `DP-1`: HP display on the right, rotated
            monitor=DP-3,preferred,0x0,1.6
            monitor=DP-4,preferred,1600x0,2
            monitor=DP-1,preferred,3520x-165,1.6,transform, 1

            # Bind workspaces to the ASUS (center)
            workspace=1,monitor:DP-4
            workspace=2,monitor:DP-4
            workspace=3,monitor:DP-4
            workspace=4,monitor:DP-4
            workspace=5,monitor:DP-4
            workspace=6,monitor:DP-4
            workspace=7,monitor:DP-4
            workspace=8,monitor:DP-4
            workspace=9,monitor:DP-4
            workspace=10,monitor:DP-4

            # Bind workspaces to the Lenovo (left)
            workspace=11,monitor:DP-3
            workspace=12,monitor:DP-3
            workspace=13,monitor:DP-3
            workspace=14,monitor:DP-3
            workspace=15,monitor:DP-3
            workspace=16,monitor:DP-3
            workspace=17,monitor:DP-3
            workspace=18,monitor:DP-3
            workspace=19,monitor:DP-3
            workspace=20,monitor:DP-3

            # Bind the extra workspace to the HP (right)
            workspace=21,monitor:DP-1
          ''
        else
          throw "Hyprland host layout is only defined for legion and fermi; got hostname=${hostname}";

      hyprConfigDir = pkgs.runCommandLocal "hypr-config-dir" { } ''
        mkdir -p "$out"
        cp ${./hypridle.conf} "$out/hypridle.conf"
        cp ${./hyprland.conf} "$out/hyprland.conf"
        cp ${./hyprlock.conf} "$out/hyprlock.conf"
        cp ${./hyprpaper.conf} "$out/hyprpaper.conf"
        chmod -R u+w "$out"
        substituteInPlace "$out/hyprlock.conf" \
          --replace-fail '__HYPRLOCK_FONT__' '${themeFonts.lock.name}' \
          --replace-fail '__HYPRLOCK_CLOCK_SIZE__' '${toString themeFonts.lock.clockSize}' \
          --replace-fail '__HYPRLOCK_DATE_SIZE__' '${toString themeFonts.lock.dateSize}' \
          --replace-fail '__HYPRLOCK_INPUT_SIZE__' '${toString themeFonts.lock.inputSize}'
        cat >> "$out/hyprland.conf" <<'EOF'

${hyprlandHostLayout}
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
        "pypr/config.toml".source = ./pyprland.toml;
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
