let
  hexDigits = {
    "0" = 0;
    "1" = 1;
    "2" = 2;
    "3" = 3;
    "4" = 4;
    "5" = 5;
    "6" = 6;
    "7" = 7;
    "8" = 8;
    "9" = 9;
    "a" = 10;
    "A" = 10;
    "b" = 11;
    "B" = 11;
    "c" = 12;
    "C" = 12;
    "d" = 13;
    "D" = 13;
    "e" = 14;
    "E" = 14;
    "f" = 15;
    "F" = 15;
  };

  pairToInt = pair:
    (hexDigits.${builtins.substring 0 1 pair} * 16) + hexDigits.${builtins.substring 1 1 pair};

  mkTheme = {
    selection,
    titles,
    mode ? "dark",
    palette,
    wallpaper,
    integrations ? { },
    cursor ? { },
    gtk ? { },
    helix ? { },
    neovim ? { },
    starship ? { },
    spicetify ? { },
    discord ? { },
    fzf ? { },
    zathura ? { },
    consoleColors ? null,
  }:
    let
      hex = name: "#${palette.${name}}";
      rgba = name: alpha:
        let
          color = palette.${name};
          red = pairToInt (builtins.substring 0 2 color);
          green = pairToInt (builtins.substring 2 2 color);
          blue = pairToInt (builtins.substring 4 2 color);
        in
        "rgba(${toString red}, ${toString green}, ${toString blue}, ${toString alpha})";

      defaultCursor = {
        name = "${titles.family}-${titles.flavor}-${titles.accent}";
        gtkName = "${titles.family}-${titles.flavor}-${titles.accent}";
        size = 24;
      };

      defaultGtk = {
        themeName = "${titles.family}-${titles.flavor}-${titles.accent}";
        iconThemeName = "hicolor";
        kvantumThemeName = "${titles.family}-${titles.flavor}-${titles.accent}";
      };

      defaultHelix = {
        themeName = "${selection.family}-${selection.flavor}";
      };

      defaultNeovim = {
        colorscheme = "default";
      };

      defaultStarship = {
        paletteName = "${selection.family}_${selection.flavor}";
      };

      defaultSpicetify = { };

      defaultDiscord = {
        themeName = "${selection.family}-${selection.flavor}-${selection.accent}";
        inherit mode;
      };

      defaultFzf = {
        defaultOpts =
          "--color=bg+:${hex "surface0"},bg:${hex "base"},spinner:${hex "rosewater"},hl:${hex "red"} "
          + "--color=fg:${hex "text"},header:${hex "red"},info:${hex "mauve"},pointer:${hex "rosewater"} "
          + "--color=marker:${hex "rosewater"},fg+:${hex "text"},prompt:${hex "mauve"},hl+:${hex "red"}";
      };

      defaultZathura = {
        highlight = rgba "surface1" 0.5;
        highlightForeground = rgba "pink" 0.5;
      };

      defaultConsoleColors = with palette; [
        base
        red
        green
        yellow
        blue
        pink
        teal
        text
        surface2
        red
        green
        yellow
        blue
        pink
        teal
        subtext0
      ];
    in
    {
      inherit palette wallpaper hex rgba;
      cursor = defaultCursor // cursor;
      gtk = defaultGtk // gtk;
      helix = defaultHelix // helix;
      neovim = defaultNeovim // neovim;
      starship = defaultStarship // starship;
      spicetify = defaultSpicetify // spicetify;
      discord = defaultDiscord // discord;
      fzf = defaultFzf // fzf;
      zathura = defaultZathura // zathura;
      consoleColors = if consoleColors == null then defaultConsoleColors else consoleColors;
      integrations = {
        grubTheme = null;
        gtkThemePackage = null;
        kvantumThemePackage = null;
        cursorThemePackage = null;
        spicetifyThemePackage = null;
        neovimThemePlugin = null;
      } // integrations;

      selection = selection;
      mode = mode;
      familyTitle = titles.family;
      flavorTitle = titles.flavor;
      accentTitle = titles.accent;
    };
in
{
  inherit hexDigits pairToInt mkTheme;
}
