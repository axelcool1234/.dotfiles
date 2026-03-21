let
  helpers = import ../helpers.nix;

  familyTitle = "Catppuccin";

  flavorTitles = {
    latte = "Latte";
    frappe = "Frappe";
    macchiato = "Macchiato";
    mocha = "Mocha";
  };

  accentTitles = {
    blue = "Blue";
    flamingo = "Flamingo";
    green = "Green";
    lavender = "Lavender";
    maroon = "Maroon";
    mauve = "Mauve";
    peach = "Peach";
    pink = "Pink";
    red = "Red";
    rosewater = "Rosewater";
    sapphire = "Sapphire";
    sky = "Sky";
    teal = "Teal";
    yellow = "Yellow";
  };

  palettes = {
    latte = {
      rosewater = "dc8a78";
      flamingo = "dd7878";
      pink = "ea76cb";
      mauve = "8839ef";
      red = "d20f39";
      maroon = "e64553";
      peach = "fe640b";
      yellow = "df8e1d";
      green = "40a02b";
      teal = "179299";
      sky = "04a5e5";
      sapphire = "209fb5";
      blue = "1e66f5";
      lavender = "7287fd";
      text = "4c4f69";
      subtext1 = "5c5f77";
      subtext0 = "6c6f85";
      overlay2 = "7c7f93";
      overlay1 = "8c8fa1";
      overlay0 = "9ca0b0";
      surface2 = "acb0be";
      surface1 = "bcc0cc";
      surface0 = "ccd0da";
      base = "eff1f5";
      mantle = "e6e9ef";
      crust = "dce0e8";
      "helix.cursorline" = "e8ecf1";
      "helix.secondary_cursor" = "e1a99d";
      "helix.secondary_cursor_select" = "97a7fb";
      "helix.secondary_cursor_normal" = "e1a99d";
      "helix.secondary_cursor_insert" = "74b867";
    };
    frappe = {
      rosewater = "f2d5cf";
      flamingo = "eebebe";
      pink = "f4b8e4";
      mauve = "ca9ee6";
      red = "e78284";
      maroon = "ea999c";
      peach = "ef9f76";
      yellow = "e5c890";
      green = "a6d189";
      teal = "81c8be";
      sky = "99d1db";
      sapphire = "85c1dc";
      blue = "8caaee";
      lavender = "babbf1";
      text = "c6d0f5";
      subtext1 = "b5bfe2";
      subtext0 = "a5adce";
      overlay2 = "949cbb";
      overlay1 = "838ba7";
      overlay0 = "737994";
      surface2 = "626880";
      surface1 = "51576d";
      surface0 = "414559";
      base = "303446";
      mantle = "292c3c";
      crust = "232634";
      "helix.cursorline" = "3b3f52";
      "helix.secondary_cursor" = "b8a5a6";
      "helix.secondary_cursor_select" = "9192be";
      "helix.secondary_cursor_normal" = "b8a5a6";
      "helix.secondary_cursor_insert" = "83a275";
    };
    macchiato = {
      rosewater = "f4dbd6";
      flamingo = "f0c6c6";
      pink = "f5bde6";
      mauve = "c6a0f6";
      red = "ed8796";
      maroon = "ee99a0";
      peach = "f5a97f";
      yellow = "eed49f";
      green = "a6da95";
      teal = "8bd5ca";
      sky = "91d7e3";
      sapphire = "7dc4e4";
      blue = "8aadf4";
      lavender = "b7bdf8";
      text = "cad3f5";
      subtext1 = "b8c0e0";
      subtext0 = "a5adcb";
      overlay2 = "939ab7";
      overlay1 = "8087a2";
      overlay0 = "6e738d";
      surface2 = "5b6078";
      surface1 = "494d64";
      surface0 = "363a4f";
      base = "24273a";
      mantle = "1e2030";
      crust = "181926";
      "helix.cursorline" = "303347";
      "helix.secondary_cursor" = "b6a6a7";
      "helix.secondary_cursor_select" = "8b91bf";
      "helix.secondary_cursor_normal" = "b6a6a7";
      "helix.secondary_cursor_insert" = "80a57a";
    };
    mocha = {
      rosewater = "f5e0dc";
      flamingo = "f2cdcd";
      pink = "f5c2e7";
      mauve = "cba6f7";
      red = "f38ba8";
      maroon = "eba0ac";
      peach = "fab387";
      yellow = "f9e2af";
      green = "a6e3a1";
      teal = "94e2d5";
      sky = "89dceb";
      sapphire = "74c7ec";
      blue = "89b4fa";
      lavender = "b4befe";
      text = "cdd6f4";
      subtext1 = "bac2de";
      subtext0 = "a6adc8";
      overlay2 = "9399b2";
      overlay1 = "7f849c";
      overlay0 = "6c7086";
      surface2 = "585b70";
      surface1 = "45475a";
      surface0 = "313244";
      base = "1e1e2e";
      mantle = "181825";
      crust = "11111b";
      "helix.cursorline" = "2a2b3c";
      "helix.secondary_cursor" = "b5a6a8";
      "helix.secondary_cursor_select" = "878ec0";
      "helix.secondary_cursor_normal" = "b5a6a8";
      "helix.secondary_cursor_insert" = "7ea87f";
    };
  };

  mkTheme = { flavor, accent, wallpaper }:
    let
      palette = palettes.${flavor};
      flavorTitle = flavorTitles.${flavor};
      accentTitle = accentTitles.${accent};
      cursorName = "${familyTitle}-${flavorTitle}-${accentTitle}";
      rgba = name: alpha:
        let
          color = palette.${name};
          red = helpers.pairToInt (builtins.substring 0 2 color);
          green = helpers.pairToInt (builtins.substring 2 2 color);
          blue = helpers.pairToInt (builtins.substring 4 2 color);
        in
        "rgba(${toString red}, ${toString green}, ${toString blue}, ${toString alpha})";
    in
    helpers.mkTheme {
      selection = {
        family = "catppuccin";
        inherit flavor accent;
      };

      titles = {
        family = familyTitle;
        flavor = flavorTitle;
        accent = accentTitle;
      };

      mode = if flavor == "latte" then "light" else "dark";

      inherit palette wallpaper;
      integrations = {
        grubTheme = {
          localPackage = ../../pkgs/catppuccin-grub.nix;
        };
        gtkThemePackage = {
          attrPath = [ "catppuccin-gtk" ];
          override = {
            accents = [ accent ];
            size = "standard";
            variant = flavor;
          };
        };
        kvantumThemePackage = {
          attrPath = [ "catppuccin-kvantum" ];
        };
        cursorThemePackage = {
          attrPath = [
            "catppuccin-cursors"
            "${flavor}${accentTitle}"
          ];
        };
        spicetifyThemePackage = {
          attrPath = [ "catppuccin" ];
          colorScheme = flavor;
        };
        neovimThemePlugin = {
          attrPath = [ "catppuccin-nvim" ];
        };
      };

      cursor = {
        name = cursorName;
        gtkName = "${cursorName}-Cursors";
        size = 24;
      };

      gtk = {
        themeName = "${familyTitle}-${flavorTitle}-Standard-${accentTitle}-dark";
        iconThemeName = "Colloid-${accent}-dark";
        kvantumThemeName = "${familyTitle}-${flavorTitle}-Standard-${accentTitle}-dark#";
      };

      helix = {
        themeName = "catppuccin-${flavor}";
      };
      neovim.colorscheme = "catppuccin-${flavor}";
      starship.paletteName = "catppuccin_${flavor}";
      spicetify = { };
      discord = {
        themeName = "catppuccin-${flavor}-${accent}";
        mode = if flavor == "latte" then "light" else "dark";
      };

      fzf.defaultOpts =
        "--color=bg+:#${palette.surface0},bg:#${palette.base},spinner:#${palette.rosewater},hl:#${palette.red} "
        + "--color=fg:#${palette.text},header:#${palette.red},info:#${palette.mauve},pointer:#${palette.rosewater} "
        + "--color=marker:#${palette.rosewater},fg+:#${palette.text},prompt:#${palette.mauve},hl+:#${palette.red}";

      zathura = {
        highlight = rgba "surface1" 0.5;
        highlightForeground = rgba "pink" 0.5;
      };

      consoleColors = with palette; [
        base red green yellow blue pink teal text
        surface2 red green yellow blue pink teal subtext0
      ];
    };
in
{
  inherit palettes mkTheme;
}
