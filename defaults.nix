{ lib, ... }:
{
  options.preferences.defaults = {
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
}
