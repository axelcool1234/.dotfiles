{ pkgs, theme, ... }:

let
  resolvePkgsAttr = spec:
    let
      pkg = builtins.getAttr (builtins.head spec.attrPath) pkgs;
      nested = builtins.foldl' (acc: name: builtins.getAttr name acc) pkg (builtins.tail spec.attrPath);
    in
    if spec ? override then nested.override spec.override else nested;

  gtkThemePkg =
    if theme.integrations.gtkThemePackage == null then null else resolvePkgsAttr theme.integrations.gtkThemePackage;

  kvantumThemePkg =
    if theme.integrations.kvantumThemePackage == null then null else resolvePkgsAttr theme.integrations.kvantumThemePackage;

  cursorThemePkg =
    if theme.integrations.cursorThemePackage == null then null else resolvePkgsAttr theme.integrations.cursorThemePackage;
in
{
  # Enable Theme
  environment.variables.GTK_THEME = theme.gtk.themeName;
  environment.variables.XCURSOR_THEME = theme.cursor.name;
  environment.variables.XCURSOR_SIZE = toString theme.cursor.size;
  environment.variables.HYPRCURSOR_THEME = theme.cursor.name;
  environment.variables.HYPRCURSOR_SIZE = toString theme.cursor.size;
  qt.enable = true;
  qt.platformTheme = "gtk2";
  qt.style = "gtk2";
  console = {
    earlySetup = true;
    colors = theme.consoleColors;
  };

  # Override packages
  nixpkgs.config.packageOverrides = pkgs: {
    colloid-icon-theme = pkgs.colloid-icon-theme.override { colorVariants = [ theme.selection.accent ]; };
  } // {
    discord = pkgs.discord.override {
      withOpenASAR = true;
      withTTS = true;
    };
  };

  environment.systemPackages = with pkgs; [
    numix-icon-theme-circle
    colloid-icon-theme
  ]
  ++ pkgs.lib.optionals (gtkThemePkg != null) [ gtkThemePkg ]
  ++ pkgs.lib.optionals (kvantumThemePkg != null) [ kvantumThemePkg ]
  ++ pkgs.lib.optionals (cursorThemePkg != null) [ cursorThemePkg ]
  ++ [

    # gnome.gnome-tweaks
    # gnome.gnome-shell
    # gnome.gnome-shell-extensions
    # xsettingsd
    # themechanger
  ];
}
