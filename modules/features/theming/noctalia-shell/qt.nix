{
  config,
  baseVars,
  hostVars,
  lib,
  pkgs,
  ...
}:
let
  uiFont = hostVars.fonts.ui;
  monospaceFont = hostVars.fonts.monospace;
  qtFont = font: "${font.family}${lib.optionalString (font.size != null) ",${toString font.size}"}";
  qt6ctConf = pkgs.writeText "qt6ct.conf" ''
    [Appearance]
    color_scheme_path=/home/${baseVars.username}/.config/qt6ct/colors/noctalia.conf
    custom_palette=true
    standard_dialogs=default
    style=Fusion

    [Fonts]
    fixed="${qtFont monospaceFont}"
    general="${qtFont uiFont}"
  '';
in
{
  config = lib.mkIf (config.preferences.desktop-shell == "noctalia-shell") {
    # https://docs.noctalia.dev/theming/program-specific/gtk-qt/

    environment.systemPackages = [ pkgs.qt6Packages.qt6ct ];

    environment.variables.QT_QPA_PLATFORMTHEME = "qt6ct";

    hjem.users.${baseVars.username} = {
      enable = true;
      clobberFiles = true;
      xdg.config.files."qt6ct/qt6ct.conf".source = qt6ctConf;
    };
  };
}
