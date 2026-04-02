{ pkgs, ... }:
let
  # Every Code's config file stores much more than the theme, so render only a
  # [tui.theme] fragment and let the wrapper merge it into ~/.code/config.toml.
  codeThemeTemplate = pkgs.writeText "every-code-theme.toml" ''
    [tui.theme]
    name = "custom"

    [tui.theme.colors]
    background = "{{colors.surface.default.hex}}"
    border = "{{colors.outline.default.hex}}"
    border_focused = "{{colors.primary.default.hex}}"
    comment = "{{colors.on_surface_variant.default.hex}}"
    cursor = "{{colors.on_surface.default.hex}}"
    error = "{{colors.error.default.hex}}"
    foreground = "{{colors.on_surface.default.hex}}"
    function = "{{colors.primary.default.hex}}"
    info = "{{colors.tertiary.default.hex}}"
    keyword = "{{colors.secondary.default.hex}}"
    primary = "{{colors.primary.default.hex}}"
    progress = "{{colors.primary.default.hex}}"
    secondary = "{{colors.secondary.default.hex}}"
    selection = "{{colors.surface_container.default.hex}}"
    spinner = "{{colors.tertiary.default.hex}}"
    string = "{{colors.secondary.default.hex}}"
    success = "{{colors.secondary.default.hex}}"
    text = "{{colors.on_surface.default.hex}}"
    text_bright = "{{colors.on_background.default.hex}}"
    text_dim = "{{colors.on_surface_variant.default.hex}}"
    warning = "{{colors.tertiary.default.hex}}"
  '';
in
{
  userTemplates = {
    templates.every-code-theme = {
      input_path = codeThemeTemplate;
      output_path = "~/.cache/noctalia/every-code-theme.toml";
    };
  };
}
