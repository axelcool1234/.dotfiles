{
  config,
  lib,
  pkgs,
  self,
  ...
}:
{
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
      pkgs.nwg-look
      pkgs.qt6Packages.qt6ct

      # Spicetify
      pkgs.spicetify-cli
    ];

    environment.sessionVariables = {
      # Tell Qt applications to use qt6ct for theme integration.
      QT_QPA_PLATFORMTHEME = "qt6ct";
    };

    # Provide the dconf/gsettings plumbing used by many GTK applications.
    programs.dconf.enable = true;

    # Set a declarative baseline GTK theme. Noctalia can still recolor and
    # manage the live theme state on top of this baseline.
    programs.dconf.profiles.user.databases = [
      {
        settings."org/gnome/desktop/interface" = {
          gtk-theme = "adw-gtk3";
          color-scheme = "prefer-dark";
        };
      }
    ];
  };
}
