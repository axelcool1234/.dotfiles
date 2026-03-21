{
  pkgs,
  themes,
  theme ? null,
  ...
}:

let
  inherit (themes.helpers) getAppProvider;

  resolvePkgsAttr = spec:
    let
      pkg = builtins.getAttr (builtins.head spec.attrPath) pkgs;
      nested = builtins.foldl' (acc: name: builtins.getAttr name acc) pkg (builtins.tail spec.attrPath);
    in
    if spec ? override then nested.override spec.override else nested;

  gtkProvider = getAppProvider theme "gtk";
  kvantumProvider = getAppProvider theme "kvantum";
  cursorProvider = getAppProvider theme "cursor";
  qtProvider = getAppProvider theme "qt";
  consoleProvider = getAppProvider theme "console";

  gtkThemeName =
    if gtkProvider != null && gtkProvider.type == "module" && gtkProvider.options ? themeName then
      gtkProvider.options.themeName
    else
      throw "theme.apps.gtk.provider.options.themeName is required";

  cursorName =
    if cursorProvider != null && cursorProvider.type == "module" && cursorProvider.options ? name then
      cursorProvider.options.name
    else
      throw "theme.apps.cursor.provider.options.name is required";

  cursorSize =
    if cursorProvider != null && cursorProvider.type == "module" && cursorProvider.options ? size then
      cursorProvider.options.size
    else
      throw "theme.apps.cursor.provider.options.size is required";

  qtEnabled =
    if qtProvider != null && qtProvider.type == "module" && qtProvider.options ? enable then
      qtProvider.options.enable
    else
      throw "theme.apps.qt.provider.options.enable is required";

  qtPlatformTheme =
    if qtProvider != null && qtProvider.type == "module" && qtProvider.options ? platformTheme then
      qtProvider.options.platformTheme
    else
      throw "theme.apps.qt.provider.options.platformTheme is required";

  qtStyle =
    if qtProvider != null && qtProvider.type == "module" && qtProvider.options ? style then
      qtProvider.options.style
    else
      throw "theme.apps.qt.provider.options.style is required";

  gtkThemeSpec =
    if gtkProvider != null
      && gtkProvider.type == "module"
      && gtkProvider.options ? package
      && gtkProvider.options.package != null then
      gtkProvider.options.package
    else
      throw "theme.apps.gtk.provider.options.package is required";

  kvantumThemeSpec =
    if kvantumProvider != null
      && kvantumProvider.type == "module"
      && kvantumProvider.options ? package
      && kvantumProvider.options.package != null then
      kvantumProvider.options.package
    else
      throw "theme.apps.kvantum.provider.options.package is required";

  cursorThemeSpec =
    if cursorProvider != null
      && cursorProvider.type == "module"
      && cursorProvider.options ? package
      && cursorProvider.options.package != null then
      cursorProvider.options.package
    else
      throw "theme.apps.cursor.provider.options.package is required";

  gtkThemePkg = resolvePkgsAttr gtkThemeSpec;

  kvantumThemePkg = resolvePkgsAttr kvantumThemeSpec;

  cursorThemePkg = resolvePkgsAttr cursorThemeSpec;

  accent =
    if theme != null && theme.source != null && theme.source ? accent then
      theme.source.accent
    else
      throw "theme.source.accent is required";
in
{
  # Enable Theme
  environment.variables.GTK_THEME = gtkThemeName;
  environment.variables.XCURSOR_THEME = cursorName;
  environment.variables.XCURSOR_SIZE = toString cursorSize;
  environment.variables.HYPRCURSOR_THEME = cursorName;
  environment.variables.HYPRCURSOR_SIZE = toString cursorSize;
  qt.enable = qtEnabled;
  qt.platformTheme = qtPlatformTheme;
  qt.style = qtStyle;
  console = {
    earlySetup = true;
    colors =
      if consoleProvider != null && consoleProvider.type == "module" && consoleProvider.options ? colors then
        consoleProvider.options.colors
      else
        throw "theme.apps.console.provider.options.colors is required";
  };

  # Override packages
  nixpkgs.config.packageOverrides = pkgs: {
    colloid-icon-theme = pkgs.colloid-icon-theme.override { colorVariants = [ accent ]; };
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
