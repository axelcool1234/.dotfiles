{
  pkgs,
  lib,
  theme ? null,
  ...
}:

let
  inherit (theme)
    isHandledByStylix
    providerFor
    moduleOption
    requireModuleOption
    ;

  gtkProvider = providerFor "gtk";
  cursorProvider = providerFor "cursor";
  qtProvider = providerFor "qt";
  consoleProvider = providerFor "console";
  kvantumProvider = providerFor "kvantum";

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

  gtkThemeName = if isHandledByStylix gtkProvider then null else requireModuleOption gtkProvider "themeName";
  gtkIconThemeSpec = if isHandledByStylix gtkProvider then null else moduleOption gtkProvider "iconPackage";

  cursorName = if isHandledByStylix cursorProvider then null else requireModuleOption cursorProvider "name";
  cursorSize = if isHandledByStylix cursorProvider then null else requireModuleOption cursorProvider "size";

  qtEnabled = if isHandledByStylix qtProvider then null else requireModuleOption qtProvider "enable";
  qtPlatformTheme = if isHandledByStylix qtProvider then null else requireModuleOption qtProvider "platformTheme";
  qtStyle = if isHandledByStylix qtProvider then null else requireModuleOption qtProvider "style";
  consoleColors = if isHandledByStylix consoleProvider then null else requireModuleOption consoleProvider "colors";

  gtkThemeSpec = if isHandledByStylix gtkProvider then null else requireModuleOption gtkProvider "package";
  kvantumThemeSpec = if isHandledByStylix kvantumProvider then null else moduleOption kvantumProvider "package";
  cursorThemeSpec = if isHandledByStylix cursorProvider then null else requireModuleOption cursorProvider "package";

  gtkThemePkg = resolveOptionalPkgsSpec gtkThemeSpec;
  gtkIconThemePkg = resolveOptionalPkgsSpec gtkIconThemeSpec;
  kvantumThemePkg = resolveOptionalPkgsSpec kvantumThemeSpec;
  cursorThemePkg = resolveOptionalPkgsSpec cursorThemeSpec;

in
lib.mkMerge [
  {
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
