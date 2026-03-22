{
  pkgs,
  lib,
  theme ? null,
  ...
}:

let
  inherit (theme)
    moduleOption
    requireModuleOption
    ;

  normalizeConsoleColor = color:
    if lib.hasPrefix "#" color then
      lib.removePrefix "#" color
    else
      color;

  resolvePkgsAttr = spec:
    let
      pkg = builtins.getAttr (builtins.head spec.attrPath) pkgs;
      nested = builtins.foldl' (acc: name: builtins.getAttr name acc) pkg (builtins.tail spec.attrPath);
    in
    if spec ? override then nested.override spec.override else nested;

  resolveOptionalPkgsSpec = spec:
    if spec != null then resolvePkgsAttr spec else null;

  gtkThemeName = requireModuleOption "gtk" "themeName";
  gtkIconThemeSpec = moduleOption "gtk" "iconPackage";

  cursorName = requireModuleOption "cursor" "name";
  cursorSize = requireModuleOption "cursor" "size";

  qtEnabled = requireModuleOption "qt" "enable";
  qtPlatformTheme = requireModuleOption "qt" "platformTheme";
  qtStyle = requireModuleOption "qt" "style";
  consoleColors = requireModuleOption "console" "colors";

  gtkThemeSpec = requireModuleOption "gtk" "package";
  kvantumThemeSpec = moduleOption "kvantum" "package";
  cursorThemeSpec = requireModuleOption "cursor" "package";

  gtkThemePkg = resolvePkgsAttr gtkThemeSpec;
  gtkIconThemePkg = resolveOptionalPkgsSpec gtkIconThemeSpec;
  kvantumThemePkg = resolveOptionalPkgsSpec kvantumThemeSpec;
  cursorThemePkg = resolvePkgsAttr cursorThemeSpec;

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
    colors = map normalizeConsoleColor consoleColors;
  };

  # Override packages
  nixpkgs.config.packageOverrides = pkgs: {
    discord = pkgs.discord.override {
      withOpenASAR = true;
      withTTS = true;
    };
  };

  environment.systemPackages = [ ]
  ++ pkgs.lib.optionals (gtkThemePkg != null) [ gtkThemePkg ]
  ++ pkgs.lib.optionals (gtkIconThemePkg != null) [ gtkIconThemePkg ]
  ++ pkgs.lib.optionals (kvantumThemePkg != null) [ kvantumThemePkg ]
  ++ pkgs.lib.optionals (cursorThemePkg != null) [ cursorThemePkg ];
}
