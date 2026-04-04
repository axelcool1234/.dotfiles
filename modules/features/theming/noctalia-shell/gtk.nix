{
  config,
  baseVars,
  hostVars,
  lib,
  pkgs,
  ...
}:
let
  gtkTheme = "adw-gtk3";
  iconTheme = "Adwaita";
  uiFont = hostVars.fonts.ui;
  fontName = "${uiFont.family}${lib.optionalString (uiFont.size != null) " ${toString uiFont.size}"}";
  cursorTheme = "Adwaita";
  cursorSize = 24;

  gtk3Settings = pkgs.writeText "gtk-3.0-settings.ini" ''
    [Settings]
    gtk-theme-name=${gtkTheme}
    gtk-icon-theme-name=${iconTheme}
    gtk-font-name=${fontName}
    gtk-cursor-theme-name=${cursorTheme}
    gtk-cursor-theme-size=${toString cursorSize}
    gtk-toolbar-style=GTK_TOOLBAR_ICONS
    gtk-toolbar-icon-size=GTK_ICON_SIZE_LARGE_TOOLBAR
    gtk-button-images=0
    gtk-menu-images=0
    gtk-enable-event-sounds=1
    gtk-enable-input-feedback-sounds=0
    gtk-xft-antialias=1
    gtk-xft-hinting=1
    gtk-xft-hintstyle=hintslight
    gtk-xft-rgba=rgb
    gtk-application-prefer-dark-theme=1
  '';

  gtk4Settings = pkgs.writeText "gtk-4.0-settings.ini" ''
    [Settings]
    gtk-theme-name=${gtkTheme}
    gtk-icon-theme-name=${iconTheme}
    gtk-font-name=${fontName}
    gtk-cursor-theme-name=${cursorTheme}
    gtk-cursor-theme-size=${toString cursorSize}
    gtk-application-prefer-dark-theme=1
  '';

  gtk2Rc = pkgs.writeText "gtkrc-2.0" ''
    gtk-theme-name="${gtkTheme}"
    gtk-icon-theme-name="${iconTheme}"
    gtk-font-name="${fontName}"
    gtk-cursor-theme-name="${cursorTheme}"
    gtk-cursor-theme-size=${toString cursorSize}
    gtk-toolbar-style=GTK_TOOLBAR_ICONS
    gtk-toolbar-icon-size=GTK_ICON_SIZE_LARGE_TOOLBAR
    gtk-button-images=0
    gtk-menu-images=0
    gtk-enable-event-sounds=1
    gtk-enable-input-feedback-sounds=0
    gtk-xft-antialias=1
    gtk-xft-hinting=1
    gtk-xft-hintstyle="hintslight"
    gtk-xft-rgba="rgb"
  '';

  gtk4Assets = "${pkgs.adw-gtk3}/share/themes/${gtkTheme}/gtk-4.0/assets";
  gtk4Css = "${pkgs.adw-gtk3}/share/themes/${gtkTheme}/gtk-4.0/gtk.css";
  gtk4DarkCss = "${pkgs.adw-gtk3}/share/themes/${gtkTheme}/gtk-4.0/gtk-dark.css";
in
{
  config = lib.mkIf (config.preferences.desktop-shell == "noctalia-shell") {
    # https://docs.noctalia.dev/theming/program-specific/gtk-qt/

    environment.systemPackages = [ pkgs.adw-gtk3 ];

    environment.variables = {
      XCURSOR_THEME = cursorTheme;
      XCURSOR_SIZE = toString cursorSize;
    };

    hjem.users.${baseVars.username} = {
      enable = true;
      clobberFiles = true;

      files.".gtkrc-2.0".source = gtk2Rc;
      xdg.config.files."gtk-3.0/settings.ini".source = gtk3Settings;
      xdg.config.files."gtk-4.0/settings.ini".source = gtk4Settings;
      xdg.config.files."gtk-4.0/assets".source = gtk4Assets;
      xdg.config.files."gtk-4.0/gtk.css".source = gtk4Css;
      xdg.config.files."gtk-4.0/gtk-dark.css".source = gtk4DarkCss;
    };
  };
}
