{ lib, ... }:
let
  importTree = import ./lib/import-tree.nix { inherit lib; };
  fontPresets = lib.mapAttrs (_name: file: import file) (importTree.entries ./fonts);
  selectedFontPreset = fontPresets."jetbrains";

  # Reuse the common option fragments across multiple font role submodules.
  # This keeps the schema consistent without repeating the same mkOption blocks.
  familyOption = {
    family = lib.mkOption {
      type = lib.types.str;
      description = "Font family name exposed to applications and fontconfig.";
    };
  };

  sizeOption = {
    # Some consumers need an explicit size, while other roles like emoji and
    # symbols do not.
    size = lib.mkOption {
      type = lib.types.nullOr lib.types.number;
      default = null;
      description = "Optional default point size for consumers that need one.";
    };
  };

  packageAttrPathOption = {
    # Font presets stay as pure data, so package lookup is deferred until the
    # host-side fonts feature resolves these nixpkgs attr paths.
    packageAttrPath = lib.mkOption {
      type = lib.types.nullOr (lib.types.listOf lib.types.str);
      default = null;
      example = [ "nerd-fonts" "jetbrains-mono" ];
      description = "Path inside nixpkgs for the package that provides this font.";
    };
  };

  postscriptNameOption = {
    # Only some terminal fonts need this.
    postscriptName = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional PostScript name for consumers such as Kitty.";
    };
  };

  fontRoleType = lib.types.submodule {
    # Generic font role used by regular UI-facing text consumers and terminal
    # fonts. Most roles ignore `postscriptName`, but terminal fonts can opt in.
    options = {
      inherit (familyOption) family;
      inherit (sizeOption) size;
      inherit (packageAttrPathOption) packageAttrPath;
      inherit (postscriptNameOption) postscriptName;
    };
  };

  familyOnlyFontRoleType = lib.types.submodule {
    # Fallback roles are only used for family-level lookup, so they do not need
    # explicit sizes.
    options = familyOption // packageAttrPathOption;
  };
in
{
  options.preferences.defaults.aliases = {
    browser = lib.mkOption {
      type = lib.types.enum [ "glide-browser" ];
      default = "glide-browser";
      description = "Default browser package alias.";
    };

    editor = lib.mkOption {
      type = lib.types.enum [ "helix" ];
      default = "helix";
      description = "Default editor package alias.";
    };

    harness = lib.mkOption {
      type = lib.types.submodule {
        options = {
          input = lib.mkOption {
            type = lib.types.str;
            default = "wrappers";
            description = "Input name to source the harness package from.";
          };

          target = lib.mkOption {
            type = lib.types.str;
            default = "code";
            description = "Package name inside the selected input.";
          };
        };
      };
      default = { };
      description = "Default harness package alias spec.";
    };

    shell = lib.mkOption {
      type = lib.types.enum [ "fish" ];
      default = "fish";
      description = "Default interactive shell package alias.";
    };

    terminal = lib.mkOption {
      type = lib.types.enum [ "kitty" ];
      default = "kitty";
      description = "Default terminal package alias.";
    };

    desktop = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum [ "niri" ]);
      default = null;
      description = "Default desktop package alias.";
    };

    desktop-shell = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum [ "noctalia-shell" ]);
      default = null;
      description = "Default desktop shell package alias.";
    };
  };

  options.preferences.defaults.fonts = {
    ui = lib.mkOption {
      type = fontRoleType;
      default = selectedFontPreset.ui;
      description = "Default UI font for toolkit and desktop-facing applications.";
    };

    monospace = lib.mkOption {
      type = fontRoleType;
      default = selectedFontPreset.monospace;
      description = "Default fixed-width font for terminal-oriented applications.";
    };

    terminal = lib.mkOption {
      type = fontRoleType;
      default = selectedFontPreset.terminal;
      description = "Terminal emulator font configuration.";
    };

    emoji = lib.mkOption {
      type = familyOnlyFontRoleType;
      default = selectedFontPreset.emoji;
      description = "Emoji fallback font.";
    };

    symbols = lib.mkOption {
      type = familyOnlyFontRoleType;
      default = selectedFontPreset.symbols;
      description = "Symbol fallback font for Nerd Font glyphs and icon-heavy prompts.";
    };
  };
}
