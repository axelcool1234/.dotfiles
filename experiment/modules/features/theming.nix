{
  config,
  baseVars,
  inputs,
  lib,
  pkgs,
  self,
  ...
}:
let
  gtkTheme = "adw-gtk3";
  iconTheme = "Adwaita";
  fontName = "Adwaita Sans 11";
  cursorTheme = "Adwaita";
  cursorSize = 24;
  pywalfoxTriggerTemplate = pkgs.writeText "pywalfox-trigger.css" ''
    /* No-op template used only to trigger pywalfox update via Noctalia post_hook. */
  '';
  nvimBase16Template = pkgs.writeText "nvim-base16-template.lua" ''
    return {
      base00 = '{{colors.surface.default.hex}}',
      base01 = '{{colors.surface_container.default.hex}}',
      base02 = '{{colors.surface_container_high.default.hex}}',
      base03 = '{{colors.outline.default.hex}}',
      base04 = '{{colors.on_surface_variant.default.hex}}',
      base05 = '{{colors.on_surface.default.hex}}',
      base06 = '{{colors.on_surface.default.hex}}',
      base07 = '{{colors.on_background.default.hex}}',
      base08 = '{{colors.error.default.hex}}',
      base09 = '{{colors.tertiary.default.hex}}',
      base0A = '{{colors.secondary.default.hex}}',
      base0B = '{{colors.primary.default.hex}}',
      base0C = '{{colors.tertiary_fixed_dim.default.hex}}',
      base0D = '{{colors.primary_fixed_dim.default.hex}}',
      base0E = '{{colors.secondary_fixed_dim.default.hex}}',
      base0F = '{{colors.error_container.default.hex}}',
    }
  '';
  noctaliaUserTemplates = (pkgs.formats.toml { }).generate "noctalia-user-templates.toml" {
    config = { };
    templates.pywalfox = {
      input_path = pywalfoxTriggerTemplate;
      output_path = "~/.cache/noctalia/pywalfox-trigger.css";
      post_hook = "${pkgs.pywalfox-native}/bin/pywalfox update";
    };
    templates.nvim-base16 = {
      input_path = nvimBase16Template;
      output_path = "~/.cache/noctalia/nvim-base16.lua";
      post_hook = "pkill -SIGUSR1 -x nvim || true";
    };
  };

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

  qt6ctConf = pkgs.writeText "qt6ct.conf" ''
    [Appearance]
    color_scheme_path=/home/${baseVars.username}/.config/qt6ct/colors/noctalia.conf
    custom_palette=true
    standard_dialogs=default
    style=Fusion
  '';

  gtk4Assets = "${pkgs.adw-gtk3}/share/themes/${gtkTheme}/gtk-4.0/assets";
  gtk4Css = "${pkgs.adw-gtk3}/share/themes/${gtkTheme}/gtk-4.0/gtk.css";
  gtk4DarkCss = "${pkgs.adw-gtk3}/share/themes/${gtkTheme}/gtk-4.0/gtk-dark.css";

in
{
  imports = [ inputs.hjem.nixosModules.default ];

  options.preferences.desktop-shell = lib.mkOption {
    type = lib.types.enum [ "noctalia-shell" ];
    default = self.defaults.desktop-shell;
    description = "Desktop shell implementation to use for the session UI layer.";
  };

  config = lib.mkIf (config.preferences.desktop-shell == "noctalia-shell") {
    # https://docs.noctalia.dev/theming/program-specific/gtk-qt/

    # The prerequisites and environment for GTK/Qt theming.
    # Noctalia still owns the active theme choice and generated theme state
    # imperatively at runtime.
    environment.systemPackages = [
      # GTK + QT
      pkgs.adw-gtk3
      pkgs.qt6Packages.qt6ct

      # Spicetify
      pkgs.spicetify-cli
    ];

    environment.variables = {
      # Tell Qt applications to use qt6ct for theme integration.
      QT_QPA_PLATFORMTHEME = "qt6ct";
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
      xdg.config.files."noctalia/user-templates.toml".source = noctaliaUserTemplates;
      xdg.config.files."qt6ct/qt6ct.conf".source = qt6ctConf;
    };
  };
}
