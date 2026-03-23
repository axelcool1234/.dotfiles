{
  pkgs,
  lib,
  theme ? null,
  ...
}:

let
  inherit (theme)
    ifNotHandledByStylix
    lookupProvider
    lookupProviderOption
    requireProviderOption
    ;

  gtkProvider = lookupProvider "gtk";
  cursorProvider = lookupProvider "cursor";
  qtProvider = lookupProvider "qt";
  consoleProvider = lookupProvider "console";
  kvantumProvider = lookupProvider "kvantum";

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

  gtkThemeName = ifNotHandledByStylix gtkProvider (provider: requireProviderOption provider "themeName");
  gtkIconThemeSpec = ifNotHandledByStylix gtkProvider (provider: lookupProviderOption provider "iconPackage");

  cursorName = ifNotHandledByStylix cursorProvider (provider: requireProviderOption provider "name");
  cursorSize = ifNotHandledByStylix cursorProvider (provider: requireProviderOption provider "size");

  qtEnabled = ifNotHandledByStylix qtProvider (provider: requireProviderOption provider "enable");
  qtPlatformTheme = ifNotHandledByStylix qtProvider (provider: requireProviderOption provider "platformTheme");
  qtStyle = ifNotHandledByStylix qtProvider (provider: requireProviderOption provider "style");
  consoleColors = ifNotHandledByStylix consoleProvider (provider: requireProviderOption provider "colors");

  gtkThemeSpec = ifNotHandledByStylix gtkProvider (provider: requireProviderOption provider "package");
  kvantumThemeSpec = ifNotHandledByStylix kvantumProvider (provider: lookupProviderOption provider "package");
  cursorThemeSpec = ifNotHandledByStylix cursorProvider (provider: requireProviderOption provider "package");

  gtkThemePkg = resolveOptionalPkgsSpec gtkThemeSpec;
  gtkIconThemePkg = resolveOptionalPkgsSpec gtkIconThemeSpec;
  kvantumThemePkg = resolveOptionalPkgsSpec kvantumThemeSpec;
  cursorThemePkg = resolveOptionalPkgsSpec cursorThemeSpec;

in
lib.mkMerge [
  {
    environment.systemPackages = [ ]
    ++ pkgs.lib.optionals (gtkThemePkg != null) [ gtkThemePkg ]
    ++ pkgs.lib.optionals (gtkIconThemePkg != null) [ gtkIconThemePkg ]
    ++ pkgs.lib.optionals (kvantumThemePkg != null) [ kvantumThemePkg ]
    ++ pkgs.lib.optionals (cursorThemePkg != null) [ cursorThemePkg ];
  }
  (lib.optionalAttrs (gtkThemeName != null) {
    environment.variables.GTK_THEME = gtkThemeName;
  })
  (lib.optionalAttrs (cursorName != null && cursorSize != null) {
    environment.variables.XCURSOR_THEME = cursorName;
    environment.variables.XCURSOR_SIZE = toString cursorSize;
    environment.variables.HYPRCURSOR_THEME = cursorName;
    environment.variables.HYPRCURSOR_SIZE = toString cursorSize;
  })
  (lib.optionalAttrs (qtEnabled != null && qtPlatformTheme != null && qtStyle != null) {
    qt.enable = qtEnabled;
    qt.platformTheme = qtPlatformTheme;
    qt.style = qtStyle;
  })
  (lib.optionalAttrs (consoleColors != null) {
    console = {
      earlySetup = true;
      colors = map normalizeConsoleColor consoleColors;
    };
  })
]
