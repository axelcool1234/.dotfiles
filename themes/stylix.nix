{ constructors, lib }:
let
  typography = import ./typography.nix;
  defaultWallpaper = ../wallpapers/nixos-catppuccin.png;
  inherit (constructors)
    mkApp
    mkStructuredProvider
    mkThemeBundle
    ;

  resolvePkgsAttr = pkgs: attrPath:
    builtins.foldl' (acc: name: builtins.getAttr name acc) pkgs attrPath;

  expectedBase16Keys = [
    "base00"
    "base01"
    "base02"
    "base03"
    "base04"
    "base05"
    "base06"
    "base07"
    "base08"
    "base09"
    "base0A"
    "base0B"
    "base0C"
    "base0D"
    "base0E"
    "base0F"
  ];

  parseBase16Scheme = schemePath:
    let
      lines = lib.splitString "\n" (builtins.readFile schemePath);
      parseLine = line:
        let
          match = builtins.match ''[[:space:]]*(base[0-9A-F]{2}):[[:space:]]*"?(#[0-9A-Fa-f]{6})"?([[:space:]]*#.*)?[[:space:]]*'' line;
        in
        if match == null then
          null
        else
          {
            name = builtins.elemAt match 0;
            value = builtins.elemAt match 1;
          };
      parsed = builtins.filter (entry: entry != null) (map parseLine lines);
      colors = builtins.listToAttrs parsed;
      missing = builtins.filter (name: !builtins.hasAttr name colors) expectedBase16Keys;
    in
    if missing != [ ] then
      throw "base16 scheme ${toString schemePath} is missing keys: ${lib.concatStringsSep ", " missing}"
    else
      colors;

  semanticPaletteFor = colors: {
    rosewater = colors.base0A;
    flamingo = colors.base08;
    pink = colors.base0E;
    mauve = colors.base0E;
    red = colors.base08;
    maroon = colors.base08;
    peach = colors.base09;
    yellow = colors.base0A;
    green = colors.base0B;
    teal = colors.base0C;
    sky = colors.base0C;
    sapphire = colors.base0D;
    blue = colors.base0D;
    lavender = colors.base0E;
    text = colors.base05;
    subtext1 = colors.base04;
    subtext0 = colors.base03;
    overlay2 = colors.base04;
    overlay1 = colors.base03;
    overlay0 = colors.base02;
    surface2 = colors.base02;
    surface1 = colors.base01;
    surface0 = colors.base01;
    base = colors.base00;
    mantle = colors.base00;
    crust = colors.base00;
  };

  stylixMeta = {
    id = "stylix";
    title = "Stylix";
  };

  mkSource =
    {
      base16Scheme ? throw "themes.stylix.mk requires source.base16Scheme",
    }:
    {
      type = "stylix";
      family = "stylix";
      variant = null;
      accent = null;
      mode = null;
      inherit base16Scheme;
    };

  mkData = source: wallpaper:
    let
      raw = parseBase16Scheme source.base16Scheme;
      palette = semanticPaletteFor raw;
    in
    {
      inherit palette raw wallpaper;
      fonts = typography;
      stylix = {
        inherit (source) base16Scheme;
        cursor = {
          packageAttrPath = [ "comixcursors" "Opaque_Blue" ];
          name = "ComixCursors-Opaque-Blue";
          size = 24;
        };
        inherit wallpaper;
      };
    };

  mkApps = source: data: let
    inherit (data)
      palette
      raw
      ;
  in {
    code = mkApp {
      provider = mkStructuredProvider {
        options = {
          stylix = true;
          colors = {
            primary = raw.base0D;
            secondary = raw.base0B;
            background = raw.base00;
            foreground = raw.base05;
            border = raw.base01;
            border_focused = raw.base02;
            selection = raw.base02;
            cursor = raw.base05;
            success = raw.base0B;
            warning = raw.base0A;
            error = raw.base08;
            info = raw.base0D;
            text = raw.base05;
            text_dim = raw.base03;
            text_bright = raw.base06;
            keyword = raw.base0E;
            string = raw.base0B;
            comment = raw.base03;
            function = raw.base0D;
            spinner = raw.base0D;
            progress = raw.base0D;
          };
        };
      };
    };

    hyprland = mkApp {
      provider = mkStructuredProvider {
        target = "dotfiles-theme/hyprland.conf";
        options = {
          stylix = true;
          colors = palette;
        };
      };
    };

    rofi = mkApp {
      provider = mkStructuredProvider {
        target = "dotfiles-theme/rofi.rasi";
        options = {
          stylix = true;
          colors = palette;
        };
      };
    };

    waybar = mkApp {
      provider = mkStructuredProvider {
        target = "dotfiles-theme/waybar.css";
        options = {
          stylix = true;
          colors = palette;
        };
      };
    };

    wlogout = mkApp {
      provider = mkStructuredProvider {
        target = "dotfiles-theme/wlogout.css";
        options = {
          stylix = true;
          colors = palette;
          accentColor = palette.blue;
        };
      };
    };
  };
in
{
  meta = stylixMeta;

  nixosModule = theme:
    { pkgs, ... }:
    let
      themeFonts = theme.requireThemeData "fonts";
      stylixData = theme.requireThemeData "stylix";
      packageFor = fontSpec: resolvePkgsAttr pkgs fontSpec.packageAttrPath;
      sansSerifFont = {
        package = packageFor themeFonts.ui;
        name = themeFonts.ui.name;
      };
    in
    {
      stylix.enable = true;
      stylix.base16Scheme = stylixData.base16Scheme;
      stylix.image = stylixData.wallpaper;
      stylix.cursor = {
        package = resolvePkgsAttr pkgs stylixData.cursor.packageAttrPath;
        inherit (stylixData.cursor)
          name
          size
          ;
      };
      stylix.fonts = {
        monospace = {
          package = packageFor themeFonts.terminal;
          name = themeFonts.terminal.family;
        };
        sansSerif = sansSerifFont;
        serif = sansSerifFont;
        emoji = {
          package = packageFor themeFonts.emoji;
          name = themeFonts.emoji.name;
        };
        sizes = {
          applications = themeFonts.ui.size;
          desktop = themeFonts.ui.size;
          popups = themeFonts.popups.size;
          terminal = themeFonts.terminal.size;
        };
      };
    };

  # Public API: build a Stylix-backed theme bundle.
  # Inputs:
  # - apps: attrset, only the custom app providers this repo should still realize
  # - data: attrset, shared derived data for custom consumers
  # - meta: attrset, additional metadata merged onto the Stylix defaults
  # - source: attrset, additional source fields merged onto { type = "stylix" }
  # - wallpaper: path, wallpaper image used by Stylix and local wallpaper consumers
  # Output:
  # - attrset theme bundle with source.type = "stylix"
  mk = {
    apps ? { },
    data ? { },
    meta ? { },
    source ? { },
    wallpaper ? defaultWallpaper,
  }:
    let
      resolvedSource = mkSource source;
      resolvedData = lib.recursiveUpdate (mkData resolvedSource wallpaper) data;
    in
    mkThemeBundle {
      meta = lib.recursiveUpdate stylixMeta meta;
      source = resolvedSource;
      apps = lib.recursiveUpdate (mkApps resolvedSource resolvedData) apps;
      data = resolvedData;
    };
}
