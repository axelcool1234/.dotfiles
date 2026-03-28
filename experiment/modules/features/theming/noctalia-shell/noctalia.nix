{
  config,
  baseVars,
  lib,
  pkgs,
  ...
}:
let
  pywalfoxTriggerTemplate = pkgs.writeText "pywalfox-trigger.css" ''
    /* No-op template used only to trigger pywalfox update via Noctalia post_hook. */
  '';

  nvimBase16Template = pkgs.writeText "nvim-base16-template.lua" ''
    return {
      base00 = '{{colors.surface.default.hex}}',
      base01 = '{{colors.surface_container.default.hex}}',
      base02 = '{{colors.surface_container_high.default.hex}}',
      base03 = '{{colors.outline.default.hex}}',
      base04 = '{{colors.on_surface_variant.default.hex}}',
      base05 = '{{colors.on_surface.default.hex}}',
      base06 = '{{colors.on_surface.default.hex}}',
      base07 = '{{colors.on_background.default.hex}}',
      base08 = '{{colors.error.default.hex}}',
      base09 = '{{colors.tertiary.default.hex}}',
      base0A = '{{colors.secondary.default.hex}}',
      base0B = '{{colors.primary.default.hex}}',
      base0C = '{{colors.tertiary_fixed_dim.default.hex}}',
      base0D = '{{colors.primary_fixed_dim.default.hex}}',
      base0E = '{{colors.secondary_fixed_dim.default.hex}}',
      base0F = '{{colors.error_container.default.hex}}',
    }
  '';

  noctaliaUserTemplates = (pkgs.formats.toml { }).generate "noctalia-user-templates.toml" {
    config = { };
    # Firefox
    templates.pywalfox = {
      input_path = pywalfoxTriggerTemplate;
      output_path = "~/.cache/noctalia/pywalfox-trigger.css";
      post_hook = "${pkgs.pywalfox-native}/bin/pywalfox update";
    };
    # Neovim
    templates.nvim-base16 = {
      input_path = nvimBase16Template;
      output_path = "~/.cache/noctalia/nvim-base16.lua";
      post_hook = "pkill -SIGUSR1 -x nvim || true";
    };
  };
in
{
  config = lib.mkIf (config.preferences.desktop-shell == "noctalia-shell") {
    environment.systemPackages = [
      pkgs.spicetify-cli
    ];

    hjem.users.${baseVars.username} = {
      enable = true;
      clobberFiles = true;
      xdg.config.files."noctalia/user-templates.toml".source = noctaliaUserTemplates;
    };
  };
}
