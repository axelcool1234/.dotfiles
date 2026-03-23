{ lib, config, theme, ... }:
with lib;
let
  program = "gtk";
  program-module = config.modules.${program};
  themeFonts = theme.requireThemeData "fonts";
  gtkProvider = theme.lookupProvider program;
  cursorProvider = theme.lookupProvider "cursor";
  gtkThemeName = theme.ifNotHandledByStylix gtkProvider (provider: theme.requireProviderOption provider "themeName");
  gtkIconThemeName = theme.ifNotHandledByStylix gtkProvider (provider: theme.requireProviderOption provider "iconThemeName");
  cursorGtkName = theme.ifNotHandledByStylix cursorProvider (provider: theme.requireProviderOption provider "gtkName");
  cursorSize = theme.ifNotHandledByStylix cursorProvider (provider: theme.requireProviderOption provider "size");
in
{
  options.modules.${program} = {
    enable = mkEnableOption "enables ${program} UI config";
  };

  config = mkIf program-module.enable {
    xdg.configFile."xsettingsd/xsettingsd.conf" = mkIf (gtkThemeName != null && gtkIconThemeName != null && cursorGtkName != null && cursorSize != null) {
      text = ''
        Net/ThemeName "${gtkThemeName}"
        Net/IconThemeName "${gtkIconThemeName}"
        Gtk/CursorThemeName "${cursorGtkName}"
        Gtk/CursorThemeSize ${toString cursorSize}
        Gtk/FontName "${themeFonts.ui.name} ${toString themeFonts.ui.size}"
        Xft/Antialias 1
        Xft/Hinting 1
        Xft/HintStyle "hintslight"
      '';
    };
    xdg.configFile."gtk-3.0/settings.ini" = mkIf (gtkThemeName != null && gtkIconThemeName != null && cursorGtkName != null && cursorSize != null) {
      text = ''
        [Settings]
        gtk-theme-name=${gtkThemeName}
        gtk-icon-theme-name=${gtkIconThemeName}
        gtk-font-name=${themeFonts.ui.name} ${toString themeFonts.ui.size}
        gtk-cursor-theme-name=${cursorGtkName}
        gtk-cursor-theme-size=${toString cursorSize}
      '';
    };
    xdg.configFile."gtk-4.0/settings.ini" = mkIf (gtkThemeName != null && gtkIconThemeName != null && cursorGtkName != null && cursorSize != null) {
      text = ''
        [Settings]
        gtk-theme-name=${gtkThemeName}
        gtk-icon-theme-name=${gtkIconThemeName}
        gtk-font-name=${themeFonts.ui.name} ${toString themeFonts.ui.size}
        gtk-cursor-theme-name=${cursorGtkName}
        gtk-cursor-theme-size=${toString cursorSize}
      '';
    };
    home.file.".gtkrc-2.0" = mkIf (gtkThemeName != null && gtkIconThemeName != null && cursorGtkName != null && cursorSize != null) {
      text = ''
        gtk-theme-name="${gtkThemeName}"
        gtk-icon-theme-name="${gtkIconThemeName}"
        gtk-cursor-theme-name="${cursorGtkName}"
        gtk-font-name="${themeFonts.ui.name} ${toString themeFonts.ui.size}"
        gtk-menu-images=0
        gtk-cursor-theme-size=${toString cursorSize}
        gtk-button-images=0
        gtk-xft-antialias=1
        gtk-xft-hinting=1
        gtk-xft-hintstyle="hintslight"
        gtk-xft-rgba="none"
        gtk-xft-dpi=98304
      '';
    };
  };
}
