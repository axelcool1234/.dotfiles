{ constructors, internal, lib }:
let
  typography = import ../typography.nix;
  inherit (constructors)
    githubPackage
    mkApp
    mkAssetProvider
    mkFamilySource
    mkStructuredProvider
    mkThemeBundle
    ;
  inherit (internal) getRgba;

  familyMeta = {
    id = "tokyonight";
    title = "Tokyo Night";
  };

  cursorThemeName = "ComixCursors-Opaque-Blue";

  defaultWallpaper = ../../wallpapers/nixos-catppuccin.png;

  rawPalettes = {
    storm = {
      bg = "#24283b";
      bg_dark = "#1f2335";
      bg_dark1 = "#1b1e2d";
      bg_highlight = "#292e42";
      blue = "#7aa2f7";
      blue0 = "#3d59a1";
      blue1 = "#2ac3de";
      blue2 = "#0db9d7";
      blue5 = "#89ddff";
      blue6 = "#b4f9f8";
      blue7 = "#394b70";
      comment = "#565f89";
      cyan = "#7dcfff";
      dark3 = "#545c7e";
      dark5 = "#737aa2";
      fg = "#c0caf5";
      fg_dark = "#a9b1d6";
      fg_gutter = "#3b4261";
      green = "#9ece6a";
      green1 = "#73daca";
      green2 = "#41a6b5";
      magenta = "#bb9af7";
      magenta2 = "#ff007c";
      orange = "#ff9e64";
      purple = "#9d7cd8";
      red = "#f7768e";
      red1 = "#db4b4b";
      teal = "#1abc9c";
      terminal_black = "#414868";
      yellow = "#e0af68";
    };
    night = {
      bg = "#1a1b26";
      bg_dark = "#16161e";
      bg_dark1 = "#0c0e14";
      bg_highlight = "#292e42";
      blue = "#7aa2f7";
      blue0 = "#3d59a1";
      blue1 = "#2ac3de";
      blue2 = "#0db9d7";
      blue5 = "#89ddff";
      blue6 = "#b4f9f8";
      blue7 = "#394b70";
      comment = "#565f89";
      cyan = "#7dcfff";
      dark3 = "#545c7e";
      dark5 = "#737aa2";
      fg = "#c0caf5";
      fg_dark = "#a9b1d6";
      fg_gutter = "#3b4261";
      green = "#9ece6a";
      green1 = "#73daca";
      green2 = "#41a6b5";
      magenta = "#bb9af7";
      magenta2 = "#ff007c";
      orange = "#ff9e64";
      purple = "#9d7cd8";
      red = "#f7768e";
      red1 = "#db4b4b";
      teal = "#1abc9c";
      terminal_black = "#414868";
      yellow = "#e0af68";
    };
    moon = {
      bg = "#222436";
      bg_dark = "#1e2030";
      bg_dark1 = "#191b29";
      bg_highlight = "#2f334d";
      blue = "#82aaff";
      blue0 = "#3e68d7";
      blue1 = "#65bcff";
      blue2 = "#0db9d7";
      blue5 = "#89ddff";
      blue6 = "#b4f9f8";
      blue7 = "#394b70";
      comment = "#636da6";
      cyan = "#86e1fc";
      dark3 = "#545c7e";
      dark5 = "#737aa2";
      fg = "#c8d3f5";
      fg_dark = "#828bb8";
      fg_gutter = "#3b4261";
      green = "#c3e88d";
      green1 = "#4fd6be";
      green2 = "#41a6b5";
      magenta = "#c099ff";
      magenta2 = "#ff007c";
      orange = "#ff966c";
      purple = "#fca7ea";
      red = "#ff757f";
      red1 = "#c53b53";
      teal = "#4fd6be";
      terminal_black = "#444a73";
      yellow = "#ffc777";
    };
  };

  variantTitle = variant:
    {
      night = "Night";
      storm = "Storm";
      moon = "Moon";
    }.${variant};

  gtkThemeNameFor = variant:
    if variant == "moon" then "Tokyonight-Dark-Moon"
    else if variant == "storm" then "Tokyonight-Dark-Storm"
    else "Tokyonight-Dark";

  gtkIconThemeNameFor = variant:
    if variant == "moon" then "Tokyonight-Moon" else "Tokyonight-Dark";

  gtkPackageOverrideFor = variant: {
    colorVariants = [ "dark" ];
    sizeVariants = [ "standard" ];
    themeVariants = [ "default" ];
    tweakVariants = if variant == "moon" then [ "moon" ] else if variant == "storm" then [ "storm" ] else [ ];
    iconVariants = if variant == "moon" then [ "Moon" ] else [ "Dark" ];
  };

  # Map Tokyonight colors to Catppuccin color format
  semanticPaletteFor = raw: {
    rosewater = raw.yellow;
    flamingo = raw.orange;
    pink = raw.magenta2;
    mauve = raw.purple;
    red = raw.red1;
    maroon = raw.red;
    peach = raw.orange;
    yellow = raw.yellow;
    green = raw.green;
    teal = raw.teal;
    sky = raw.cyan;
    sapphire = raw.blue1;
    blue = raw.blue;
    lavender = raw.magenta;
    text = raw.fg;
    subtext1 = raw.fg_dark;
    subtext0 = raw.dark5;
    overlay2 = raw.dark5;
    overlay1 = raw.comment;
    overlay0 = raw.dark3;
    surface2 = raw.terminal_black;
    surface1 = raw.bg_highlight;
    surface0 = raw.bg; # still unsure if this swap with base looks good
    base = raw.bg_dark; # still unsure if this swap with surface0 looks good
    mantle = raw.bg_dark;
    crust = raw.bg_dark1;
  };

  mkSource = {
    variant ? "night",
  }:
    mkFamilySource {
      family = familyMeta.id;
      inherit variant;
      mode = "dark";
    };

  mkApps = source:
    let
      inherit (source) variant;
      raw = rawPalettes.${variant};
      palette = semanticPaletteFor raw;
      gtkThemeName = gtkThemeNameFor variant;
      gtkIconThemeName = gtkIconThemeNameFor variant;
    in
    {
      btop = mkApp {
        provider = mkAssetProvider {
          package = githubPackage {
            repo = "folke/tokyonight.nvim";
            rev = "5da1b76e64daf4c5d410f06bcb6b9cb640da7dfd";
          };
          source = "extras/btop/tokyonight_${variant}.theme";
          target = "dotfiles-theme/btop.theme";
        };
      };

      discord = mkApp {
        provider = mkAssetProvider {
          package = githubPackage {
            repo = "folke/tokyonight.nvim";
            rev = "5da1b76e64daf4c5d410f06bcb6b9cb640da7dfd";
          };
          source = "extras/discord/tokyonight_${variant}.css";
          target = "dotfiles-theme/discord.css";
        };
      };

      dunst = mkApp {
        provider = mkAssetProvider {
          package = githubPackage {
            repo = "folke/tokyonight.nvim";
            rev = "5da1b76e64daf4c5d410f06bcb6b9cb640da7dfd";
          };
          source = "extras/dunst/tokyonight_${variant}.dunstrc";
          target = "dunst/dunstrc.d/tokyonight.conf";
        };
      };

      code = mkApp {
        provider = mkStructuredProvider {
          options.colors = {
            primary = raw.blue;
            secondary = raw.green;
            background = raw.bg;
            foreground = raw.fg;
            border = raw.bg_highlight;
            border_focused = raw.dark3;
            selection = raw.bg_highlight;
            cursor = raw.fg;
            success = raw.green;
            warning = raw.yellow;
            error = raw.red;
            info = raw.cyan;
            text = raw.fg;
            text_dim = raw.dark5;
            text_bright = raw.fg;
            keyword = raw.magenta;
            string = raw.green;
            comment = raw.comment;
            function = raw.blue;
            spinner = raw.blue1;
            progress = raw.blue;
          };
        };
      };

      fish = mkApp {
        provider = mkAssetProvider {
          package = githubPackage {
            repo = "folke/tokyonight.nvim";
            rev = "5da1b76e64daf4c5d410f06bcb6b9cb640da7dfd";
          };
          source = "extras/fish_themes/tokyonight_${variant}.theme";
          target = "dotfiles-theme/fish.fish";
        };
      };

      grub = mkApp {
        provider = mkAssetProvider {
          package = githubPackage {
            repo = "mino29/tokyo-night-grub";
            rev = "e2b2cfd77f0195fffa93b36959f9b970ca7a1307";
          };
          source = "tokyo-night";
          target = null;
          notes = [
            "Uses the upstream Tokyo Night GRUB theme directory directly."
          ];
        };
      };

      helix = mkApp {
        provider = mkStructuredProvider {
          options.themeName =
            if variant == "night" then
              "tokyonight"
            else
              "tokyonight_${variant}";
        };
      };

      fzf = mkApp {
        provider = mkAssetProvider {
          package = githubPackage {
            repo = "folke/tokyonight.nvim";
            rev = "5da1b76e64daf4c5d410f06bcb6b9cb640da7dfd";
          };
          source = "extras/fzf/tokyonight_${variant}.sh";
          target = "dotfiles-theme/fzf.nu";
        };
      };

      gtk = mkApp {
        provider = mkStructuredProvider {
          attrPath = [ "tokyonight-gtk-theme" ];
          options = {
            themeName = gtkThemeName;
            iconThemeName = gtkIconThemeName;
            package = {
              attrPath = [ "tokyonight-gtk-theme" ];
              override = gtkPackageOverrideFor variant;
            };
          };
        };
      };

      kvantum = mkApp {
        provider = mkAssetProvider {
          package = githubPackage {
            repo = "0xsch1zo/Kvantum-Tokyo-Night";
            rev = "82d104e0047fa7d2b777d2d05c3f22722419b9ee";
          };
          source = "Kvantum-Tokyo-Night";
          target = "Kvantum/Kvantum-Tokyo-Night";
          options.themeName = "Kvantum-Tokyo-Night";
        };
      };

      cursor = mkApp {
        provider = mkStructuredProvider {
          options = {
            name = cursorThemeName;
            gtkName = cursorThemeName;
            size = 24;
            package = {
              attrPath = [
                "comixcursors"
                "Opaque_Blue"
              ];
            };
          };
        };
      };

      qt = mkApp {
        provider = mkStructuredProvider {
          options = {
            enable = true;
            platformTheme = "gtk2";
            style = "gtk2";
          };
        };
      };

      kitty = mkApp {
        provider = mkAssetProvider {
          package = githubPackage {
            repo = "folke/tokyonight.nvim";
            rev = "5da1b76e64daf4c5d410f06bcb6b9cb640da7dfd";
          };
          source = "extras/kitty/tokyonight_${variant}.conf";
          target = "dotfiles-theme/kitty.conf";
        };
      };

      neovim = mkApp {
        provider = mkStructuredProvider {
          attrPath = [ "tokyonight-nvim" ];
          options.colorscheme = "tokyonight-${variant}";
        };
      };

      console = mkApp {
        provider = mkStructuredProvider {
          options.colors = with raw; [
            bg red green yellow blue magenta cyan fg
            terminal_black red1 green1 orange blue1 magenta2 cyan fg_dark
          ];
        };
      };

      lazygit = mkApp {
        provider = mkAssetProvider {
          package = githubPackage {
            repo = "folke/tokyonight.nvim";
            rev = "5da1b76e64daf4c5d410f06bcb6b9cb640da7dfd";
          };
          source = "extras/lazygit/tokyonight_${variant}.yml";
          target = "lazygit/config.yml";
        };
      };

      spicetify = mkApp {
        provider = mkAssetProvider {
          package = githubPackage {
            repo = "stronk-dev/Tokyo-Night-Linux";
            rev = "11ae4614f79637033ab5f948554e316a810e1025";
          };
          source = ".config/spicetify/Themes/Base";
          target = null;
          options = {
            name = "Base";
            colorScheme = "Base";
          };
        };
      };

      nushell = mkApp {
        provider = mkStructuredProvider {
          options.colors = palette;
        };
      };

      starship = mkApp {
        provider = mkStructuredProvider {
          options = {
            paletteName = "tokyonight_${variant}";
            colors = {
              blue = raw.blue;
              green = raw.green;
              red = raw.red;
              yellow = raw.yellow;
              cyan = raw.cyan;
              magenta = raw.magenta;
              purple = raw.purple;
              orange = raw.orange;
              fg = raw.fg;
              fg_dark = raw.fg_dark;
              comment = raw.comment;
              bg = raw.bg;
              bg_dark = raw.bg_dark;
              bg_highlight = raw.bg_highlight;
            };
          };
        };
      };

      rofi = mkApp {
        provider = mkStructuredProvider {
          target = "dotfiles-theme/rofi.rasi";
          options = {
            colors = palette;
          };
        };
      };

      waybar = mkApp {
        provider = mkStructuredProvider {
          target = "dotfiles-theme/waybar.css";
          options = {
            colors = palette;
          };
        };
      };

      wlogout = mkApp {
        provider = mkStructuredProvider {
          target = "dotfiles-theme/wlogout.css";
          options = {
            colors = palette;
            accentColor = palette.blue;
          };
        };
      };

      hyprland = mkApp {
        provider = mkStructuredProvider {
          target = "dotfiles-theme/hyprland.conf";
          options.colors = palette;
        };
      };

      yazi = mkApp {
        provider = mkAssetProvider {
          package = githubPackage {
            repo = "folke/tokyonight.nvim";
            rev = "5da1b76e64daf4c5d410f06bcb6b9cb640da7dfd";
          };
          source = "extras/yazi/tokyonight_${variant}.toml";
          target = "yazi/theme.toml";
        };
      };

      yaziSyntectTheme = mkApp {
        provider = mkAssetProvider {
          package = githubPackage {
            repo = "folke/tokyonight.nvim";
            rev = "5da1b76e64daf4c5d410f06bcb6b9cb640da7dfd";
          };
          source = "extras/sublime/tokyonight_${variant}.tmTheme";
          target = "yazi/tokyonight_${variant}.tmTheme";
        };
      };

      zathura = mkApp {
        provider = mkAssetProvider {
          package = githubPackage {
            repo = "folke/tokyonight.nvim";
            rev = "5da1b76e64daf4c5d410f06bcb6b9cb640da7dfd";
          };
          source = "extras/zathura/tokyonight_${variant}.zathurarc";
          target = "dotfiles-theme/zathura";
        };
      };
    };

  mkData = source: wallpaper:
    let
      raw = rawPalettes.${source.variant};
      palette = semanticPaletteFor raw;
    in
    {
      inherit palette wallpaper;
      fonts = typography;
    };

  mk = {
    source ? { },
    apps ? { },
    meta ? { },
    wallpaper ? defaultWallpaper,
  }:
    let
      resolvedSource = mkSource source;
      resolvedData = mkData resolvedSource wallpaper;
    in
    mkThemeBundle {
      meta = lib.recursiveUpdate familyMeta {
        variant = resolvedSource.variant;
        variantTitle = variantTitle resolvedSource.variant;
      } // meta;
      source = resolvedSource;
      apps = lib.recursiveUpdate (mkApps resolvedSource) apps;
      data = resolvedData;
    };
in
{
  meta = familyMeta;
  inherit mk;
}
