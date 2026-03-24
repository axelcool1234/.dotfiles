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

  # Family-level identity used by all Catppuccin bundles.
  familyMeta = {
    id = "catppuccin";
    title = "Catppuccin";
  };

  variants = [ "latte" "frappe" "macchiato" "mocha" ];
  accents = [
    "rosewater"
    "flamingo"
    "pink"
    "mauve"
    "red"
    "maroon"
    "peach"
    "yellow"
    "green"
    "teal"
    "sky"
    "sapphire"
    "blue"
    "lavender"
  ];

  # Default wallpaper used unless the caller overrides it in `mk`.
  defaultWallpaper = ../../wallpapers/nixos-catppuccin.png;

  # Embedded Catppuccin palettes. These remain local because several apps still need
  # family-specific derived values even when their primary theme asset is upstream.
  palettes = {
    latte = {
      rosewater = "#dc8a78";
      flamingo = "#dd7878";
      pink = "#ea76cb";
      mauve = "#8839ef";
      red = "#d20f39";
      maroon = "#e64553";
      peach = "#fe640b";
      yellow = "#df8e1d";
      green = "#40a02b";
      teal = "#179299";
      sky = "#04a5e5";
      sapphire = "#209fb5";
      blue = "#1e66f5";
      lavender = "#7287fd";
      text = "#4c4f69";
      subtext1 = "#5c5f77";
      subtext0 = "#6c6f85";
      overlay2 = "#7c7f93";
      overlay1 = "#8c8fa1";
      overlay0 = "#9ca0b0";
      surface2 = "#acb0be";
      surface1 = "#bcc0cc";
      surface0 = "#ccd0da";
      base = "#eff1f5";
      mantle = "#e6e9ef";
      crust = "#dce0e8";
      "helix.cursorline" = "#e8ecf1";
      "helix.secondary_cursor" = "#e1a99d";
      "helix.secondary_cursor_select" = "#97a7fb";
      "helix.secondary_cursor_normal" = "#e1a99d";
      "helix.secondary_cursor_insert" = "#74b867";
    };
    frappe = {
      rosewater = "#f2d5cf";
      flamingo = "#eebebe";
      pink = "#f4b8e4";
      mauve = "#ca9ee6";
      red = "#e78284";
      maroon = "#ea999c";
      peach = "#ef9f76";
      yellow = "#e5c890";
      green = "#a6d189";
      teal = "#81c8be";
      sky = "#99d1db";
      sapphire = "#85c1dc";
      blue = "#8caaee";
      lavender = "#babbf1";
      text = "#c6d0f5";
      subtext1 = "#b5bfe2";
      subtext0 = "#a5adce";
      overlay2 = "#949cbb";
      overlay1 = "#838ba7";
      overlay0 = "#737994";
      surface2 = "#626880";
      surface1 = "#51576d";
      surface0 = "#414559";
      base = "#303446";
      mantle = "#292c3c";
      crust = "#232634";
      "helix.cursorline" = "#3b3f52";
      "helix.secondary_cursor" = "#b8a5a6";
      "helix.secondary_cursor_select" = "#9192be";
      "helix.secondary_cursor_normal" = "#b8a5a6";
      "helix.secondary_cursor_insert" = "#83a275";
    };
    macchiato = {
      rosewater = "#f4dbd6";
      flamingo = "#f0c6c6";
      pink = "#f5bde6";
      mauve = "#c6a0f6";
      red = "#ed8796";
      maroon = "#ee99a0";
      peach = "#f5a97f";
      yellow = "#eed49f";
      green = "#a6da95";
      teal = "#8bd5ca";
      sky = "#91d7e3";
      sapphire = "#7dc4e4";
      blue = "#8aadf4";
      lavender = "#b7bdf8";
      text = "#cad3f5";
      subtext1 = "#b8c0e0";
      subtext0 = "#a5adcb";
      overlay2 = "#939ab7";
      overlay1 = "#8087a2";
      overlay0 = "#6e738d";
      surface2 = "#5b6078";
      surface1 = "#494d64";
      surface0 = "#363a4f";
      base = "#24273a";
      mantle = "#1e2030";
      crust = "#181926";
      "helix.cursorline" = "#303347";
      "helix.secondary_cursor" = "#b6a6a7";
      "helix.secondary_cursor_select" = "#8b91bf";
      "helix.secondary_cursor_normal" = "#b6a6a7";
      "helix.secondary_cursor_insert" = "#80a57a";
    };
    mocha = {
      rosewater = "#f5e0dc";
      flamingo = "#f2cdcd";
      pink = "#f5c2e7";
      mauve = "#cba6f7";
      red = "#f38ba8";
      maroon = "#eba0ac";
      peach = "#fab387";
      yellow = "#f9e2af";
      green = "#a6e3a1";
      teal = "#94e2d5";
      sky = "#89dceb";
      sapphire = "#74c7ec";
      blue = "#89b4fa";
      lavender = "#b4befe";
      text = "#cdd6f4";
      subtext1 = "#bac2de";
      subtext0 = "#a6adc8";
      overlay2 = "#9399b2";
      overlay1 = "#7f849c";
      overlay0 = "#6c7086";
      surface2 = "#585b70";
      surface1 = "#45475a";
      surface0 = "#313244";
      base = "#1e1e2e";
      mantle = "#181825";
      crust = "#11111b";
      "helix.cursorline" = "#2a2b3c";
      "helix.secondary_cursor" = "#b5a6a8";
      "helix.secondary_cursor_select" = "#878ec0";
      "helix.secondary_cursor_normal" = "#b5a6a8";
      "helix.secondary_cursor_insert" = "#7ea87f";
    };
  };

  # Convert a lowercase flavor/accent key into display text.
  titleCase = s:
    let
      len = builtins.stringLength s;
    in
    if len == 0 then
      s
    else
      "${lib.toUpper (builtins.substring 0 1 s)}${builtins.substring 1 (len - 1) s}";

  # Build the top-level source selection for this family.
  mkSource = {
    variant ? "mocha",
    accent ? "teal",
  }:
    mkFamilySource {
      family = familyMeta.id;
      inherit variant accent;
      mode = if variant == "latte" then "light" else "dark";
    };

  # Build all app delivery records for a selected Catppuccin source.
  mkApps = source:
    let
      inherit (source) variant accent;

      # Common display names reused across several providers.
      flavorTitle = titleCase variant;
      accentTitle = titleCase accent;
      familyTitle = "Catppuccin";
      palette = palettes.${variant};

      cursorThemeName = "catppuccin-${variant}-${accent}-cursors";
      gtkThemeName = "catppuccin-${variant}-${accent}-standard";
      iconThemeName = "Colloid-${accentTitle}-${if variant == "latte" then "Light" else "Dark"}";
    in
    {
      # Upstream asset-based apps: copy or import shipped Catppuccin theme files.
      btop = mkApp {
        provider = mkAssetProvider {
          package = githubPackage {
            repo = "catppuccin/btop";
            rev = "f437574b600f1c6d932627050b15ff5153b58fa3";
          };
          source = "themes/catppuccin_${variant}.theme";
          target = "dotfiles-theme/btop.theme";
        };
      };

      discord = mkApp {
        provider = mkAssetProvider {
          package = githubPackage {
            repo = "catppuccin/discord";
            rev = "b9b5547f0b32296d2389716ef606de87b3c1e7c7";
          };
          source = "themes/${variant}.theme.css";
          target = "dotfiles-theme/discord.css";
        };
      };

      fish = mkApp {
        provider = mkAssetProvider {
          package = githubPackage {
            repo = "catppuccin/fish";
            rev = "5fc5ae9c2ec22eb376cb03ce76f0d262a38960f3";
          };
          source = "themes/static/catppuccin-${variant}.theme";
          target = "dotfiles-theme/fish.fish";
        };
      };

      helix = mkApp {
        provider = mkAssetProvider {
          package = githubPackage {
            repo = "catppuccin/helix";
            rev = "91e071bf9b9b2b8ae176a5581fcb61c789c55cab";
          };
          source = "themes/default/catppuccin_${variant}.toml";
          target = "helix/themes/catppuccin-${variant}.toml";
          options.themeName = "catppuccin-${variant}";
        };
      };

      grub = mkApp {
        provider = mkAssetProvider {
          package = githubPackage {
            repo = "catppuccin/grub";
            rev = "0a37ab19f654e77129b409fed371891c01ffd0b9";
          };
          source = "src/catppuccin-${variant}-grub-theme";
          target = null;
        };
      };

      code = mkApp {
        # Code is the one intentionally manual app in this family.
        provider = mkStructuredProvider {
          options.colors = {
            primary = palettes.${variant}.blue;
            secondary = palettes.${variant}.green;
            background = palettes.${variant}.base;
            foreground = palettes.${variant}.text;
            border = palettes.${variant}.surface1;
            border_focused = palettes.${variant}.overlay0;
            selection = palettes.${variant}.surface0;
            cursor = palettes.${variant}.rosewater;
            success = palettes.${variant}.green;
            warning = palettes.${variant}.yellow;
            error = palettes.${variant}.red;
            info = palettes.${variant}.sky;
            text = palettes.${variant}.text;
            text_dim = palettes.${variant}.subtext0;
            text_bright = palettes.${variant}.rosewater;
            keyword = palettes.${variant}.mauve;
            string = palettes.${variant}.green;
            comment = palettes.${variant}.overlay1;
            function = palettes.${variant}.blue;
            spinner = palettes.${variant}.sapphire;
            progress = palettes.${variant}.blue;
          };
        };
      };

      dunst = mkApp {
        provider = mkAssetProvider {
          package = githubPackage {
            repo = "catppuccin/dunst";
            rev = "5955cf0213d14a3494ec63580a81818b6f7caa66";
          };
          source = "themes/${variant}.conf";
          target = "dunst/dunstrc.d/catppuccin.conf";
        };
      };

      lazygit = mkApp {
        provider = mkAssetProvider {
          package = githubPackage {
            repo = "catppuccin/lazygit";
            rev = "c24895902ec2a3cb62b4557f6ecd8e0afeed95d5";
          };
          source = "themes/${variant}/${accent}.yml";
          target = "lazygit/config.yml";
        };
      };

      starship = mkApp {
        provider = mkAssetProvider {
          package = githubPackage {
            repo = "catppuccin/starship";
            rev = "5906cc369dd8207e063c0e6e2d27bd0c0b567cb8";
          };
          source = "themes/${variant}.toml";
          target = "starship.toml";
        };
      };

      gtk = mkApp {
        # GTK/desktop integrations are package-backed rather than asset-backed.
        provider = mkStructuredProvider {
          attrPath = [ "catppuccin-gtk" ];
          options = {
            themeName = gtkThemeName;
            iconThemeName = iconThemeName;
            iconPackage = {
              attrPath = [ "colloid-icon-theme" ];
              override = {
                colorVariants = [ accent ];
              };
            };
            package = {
              attrPath = [ "catppuccin-gtk" ];
              override = {
                accents = [ accent ];
                size = "standard";
                variant = variant;
              };
            };
          };
        };
      };

      kvantum = mkApp {
        provider = mkStructuredProvider {
          attrPath = [ "catppuccin-kvantum" ];
          options = {
            themeName = "catppuccin-${variant}-${accent}";
            package = {
              attrPath = [ "catppuccin-kvantum" ];
              override = {
                inherit accent variant;
              };
            };
          };
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
                "catppuccin-cursors"
                "${variant}${accentTitle}"
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
            repo = "catppuccin/kitty";
            rev = "43098316202b84d6a71f71aaf8360f102f4d3f1a";
          };
          source = "themes/${variant}.conf";
          target = "dotfiles-theme/kitty.conf";
        };
      };

      neovim = mkApp {
        provider = mkStructuredProvider {
          attrPath = [ "catppuccin-nvim" ];
          package = githubPackage {
            repo = "catppuccin/nvim";
          };
          options.colorscheme = "catppuccin-${variant}";
        };
      };

      console = mkApp {
        # Console colors are realized by the NixOS module, not copied into XDG config.
        provider = mkStructuredProvider {
          options.colors = with palettes.${variant}; [
            base red green yellow blue pink teal text
            surface2 red green yellow blue pink teal subtext0
          ];
        };
      };

      nushell = mkApp {
        provider = mkAssetProvider {
          package = githubPackage {
            repo = "catppuccin/nushell";
            rev = "815dfc6ea61f2746ff27b54ef425cfeb7b51dda8";
          };
          source = "themes/catppuccin_${variant}.nu";
          target = "dotfiles-theme/nushell.nu";
        };
      };

      fzf = mkApp {
        provider = mkAssetProvider {
          package = githubPackage {
            repo = "catppuccin/fzf";
            rev = "7c2e05606f2e75840b1ba367b1f997cd919809b3";
          };
          source = "themes/catppuccin-fzf-${variant}.nu";
          target = "dotfiles-theme/fzf.nu";
        };
      };

      rofi = mkApp {
        provider = mkAssetProvider {
          package = githubPackage {
            repo = "catppuccin/rofi";
            rev = "71fb15577ccb091df2f4fc1f65710edbc61b5a53";
          };
          source = "themes/catppuccin-${variant}.rasi";
          target = "dotfiles-theme/rofi.rasi";
        };
      };

      waybar = mkApp {
        # Waybar also exposes a small shared color set for the
        # Hyprland desktop module's inline markup strings.
        provider = mkAssetProvider {
          package = githubPackage {
            repo = "catppuccin/waybar";
            rev = "ee8ed32b4f63e9c417249c109818dcc05a2e25da";
          };
          source = "themes/${variant}.css";
          target = "dotfiles-theme/waybar.css";
          options.colors = palette;
        };
      };

      wlogout = mkApp {
        provider = mkStructuredProvider {
          target = "dotfiles-theme/wlogout.css";
          options = {
            colors = palettes.${variant};
            accentColor = palettes.${variant}.${accent};
          };
        };
      };

      yazi = mkApp {
        provider = mkAssetProvider {
          package = githubPackage {
            repo = "catppuccin/yazi";
            rev = "fc69d6472d29b823c4980d23186c9c120a0ad32c";
          };
          source = "themes/${variant}/catppuccin-${variant}-${accent}.toml";
          target = "yazi/theme.toml";
        };
      };

      zathura = mkApp {
        provider = mkAssetProvider {
          package = githubPackage {
            repo = "catppuccin/zathura";
            rev = "9f29c2c1622c70436f0e0b98fea9735863596c1e";
          };
          source = "themes/catppuccin-${variant}";
          target = "dotfiles-theme/zathura";
        };
      };

      hyprland = mkApp {
        provider = mkAssetProvider {
          package = githubPackage {
            repo = "catppuccin/hyprland";
            rev = "c388ac55563ddeea0afe9df79d4bfff0096b146b";
          };
          source = "themes/${variant}.conf";
          target = "dotfiles-theme/hyprland.conf";
        };
      };

      yaziSyntectTheme = mkApp {
        # Uses the upstream Catppuccin bat tmTheme for Yazi syntect previews.
        provider = mkAssetProvider {
          package = githubPackage {
            repo = "catppuccin/bat";
            rev = "6810349b28055dce54076712fc05fc68da4b8ec0";
          };
          source = "themes/Catppuccin ${titleCase variant}.tmTheme";
          target = "yazi/catppuccin-${variant}-${accent}.tmTheme";
          options = {
            aliases = [
              "yazi/catppuccin-${variant}.tmTheme"
              "yazi/Catppuccin-${variant}.tmTheme"
            ];
          };
        };
      };

      spicetify = mkApp {
        provider = mkStructuredProvider {
          attrPath = [ "catppuccin" ];
          options = {
            colorScheme = variant;
          };
        };
      };
    };

  # Shared derived data that is still useful outside individual app records.
  mkData = source: wallpaper:
    let
      inherit (source) variant;
      palette = palettes.${variant};
    in
    {
      inherit palette;
      inherit wallpaper;
      fonts = typography;
    };

  # Public constructor for a selected Catppuccin bundle.
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
        accent = resolvedSource.accent;
        variantTitle = titleCase resolvedSource.variant;
        accentTitle = titleCase resolvedSource.accent;
      } // meta;
      source = resolvedSource;
      apps = lib.recursiveUpdate (mkApps resolvedSource) apps;
      data = resolvedData;
    };
in
{
  meta = familyMeta;
  inherit accents mk variants;
}
