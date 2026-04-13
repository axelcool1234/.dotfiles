{ pkgs, ... }:
let
  # Own Helix's Noctalia theme from our config layer instead of using
  # Noctalia's built-in Helix template. The syntax colors intentionally mirror
  # base16-nvim's highlight table, while the UI keeps Noctalia role names.
  helixThemeTemplate = pkgs.writeText "helix-noctalia-template.toml" ''
    # Syntax highlighting
    # -------------------
    "attribute" = "base0A"

    "type" = "base05"
    "type.builtin" = { fg = "base05", modifiers = ["italic"] }
    "type.parameter" = "base05"
    "type.enum.variant" = "base09"

    "constructor" = "base0D"

    "constant" = "base09"
    "constant.builtin" = "base09"
    "constant.builtin.boolean" = "base09"
    "constant.numeric" = "base09"
    "constant.numeric.integer" = "base09"
    "constant.numeric.float" = "base09"
    "constant.character" = "base08"
    "constant.character.escape" = "base0C"
    "boolean" = "base09"
    "character" = "base08"

    "string" = "base0B"
    "string.regexp" = "base0C"
    "string.special" = "base0F"
    "string.special.symbol" = "base0B"
    "string.special.path" = { fg = "base09", underline = { color = "base09", style = "line" } }
    "string.special.url" = { fg = "base09", underline = { color = "base09", style = "line" } }

    "path" = { fg = "base09", underline = { color = "base09", style = "line" } }

    "comment" = { fg = "base03", modifiers = ["italic"] }

    "variable" = "base05"
    "variable.builtin" = { fg = "base08", modifiers = ["italic"] }
    "variable.parameter" = "base05"
    "variable.other.member" = "base05"

    "label" = "base0A"

    "punctuation" = "base0F"
    "punctuation.bracket" = "base0F"
    "punctuation.delimiter" = "base0E"
    "punctuation.special" = "base0F"

    "keyword" = "base0E"
    "keyword.control.conditional" = "base0E"
    "keyword.control.repeat" = "base0E"
    "keyword.control.import" = "base0D"
    "keyword.control.return" = "base0E"
    "keyword.control.exception" = "base08"
    "keyword.directive" = "base0A"
    "keyword.function" = "base0E"
    "keyword.operator" = "base0E"
    "keyword.storage" = "base0A"
    "keyword.storage.type" = "base0A"
    "keyword.storage.modifier" = "base08"

    "operator" = "base05"

    "function" = "base0D"
    "function.builtin" = { fg = "base0D", modifiers = ["italic"] }
    "function.macro" = "base08"
    "function.method" = "base0D"

    "tag" = "base08"
    "tag.builtin" = "base08"

    "namespace" = "base08"

    "special" = "base0C"

    "lsp.type.namespace" = "base08"
    "lsp.type.type.definition" = "base0B"
    "lsp.type.class.definition" = "base0B"
    "lsp.type.struct.definition" = "base0B"
    "lsp.type.enum.definition" = "base0B"
    "lsp.type.interface.definition" = "base0B"
    "lsp.type.type.declaration" = "base0B"
    "lsp.type.class.declaration" = "base0B"
    "lsp.type.struct.declaration" = "base0B"
    "lsp.type.enum.declaration" = "base0B"
    "lsp.type.interface.declaration" = "base0B"
    "lsp.type.type" = "base05"
    "lsp.type.class" = "base05"
    "lsp.type.struct" = "base05"
    "lsp.type.enum" = "base05"
    "lsp.type.interface" = "base05"
    "lsp.type.parameter" = "base05"
    "lsp.type.variable" = "base05"
    "lsp.type.property" = "base05"
    "lsp.type.enumMember" = "base09"
    "lsp.type.function" = "base0D"
    "lsp.type.method" = "base0D"
    "lsp.type.macro" = "base08"
    "lsp.type.keyword" = "base0E"
    "lsp.type.operator" = "base05"
    "lsp.type.comment" = { fg = "base03", modifiers = ["italic"] }
    "lsp.type.string" = "base0B"
    "lsp.type.number" = "base09"
    "lsp.type.leanSorryLike" = "error"

    "lean.info.goals_accomplished" = "base0B"
    "lean.info.goal_case" = "base0E"
    "lean.info.goal_prefix" = "base0A"
    "lean.info.hyp_name" = "base0D"
    "lean.info.expected_type" = "base09"
    "lean.info.diagnostic.error" = "error"
    "lean.info.diagnostic.warning" = "warning"
    "lean.info.diagnostic.info" = "info"
    "lean.info.diagnostic.hint" = "hint"

    "markup.heading" = "base0D"
    "markup.list" = "base0F"
    "markup.bold" = { modifiers = ["bold"] }
    "markup.italic" = { modifiers = ["italic"] }
    "markup.link.url" = { fg = "base09", underline = { color = "base09", style = "line" } }
    "markup.link.label" = "base0F"
    "markup.raw" = "base09"
    "markup.quote" = "base0A"

    "diff.plus" = "base0B"
    "diff.minus" = "base08"
    "diff.delta" = "base09"

    # User Interface
    # --------------
    "ui.background" = "none"

    "ui.cursor" = { fg = "onSecondary", bg = "secondary" }
    "ui.cursor.match" = { fg = "onTertiary", bg = "tertiary", modifiers = ["bold"] }
    "ui.cursor.primary" = { fg = "onPrimary", bg = "primary" }

    "ui.linenr" = { fg = "onSurfaceVariant" }
    "ui.linenr.selected" = { fg = "primary" }

    "ui.statusline" = { fg = "onSurface", bg = "surfaceContainerLow" }
    "ui.statusline.inactive" = { fg = "onSurface", bg = "surfaceContainerLowest" }
    "ui.statusline.normal" = { fg = "onPrimary", bg = "primary", modifiers = ["bold"] }
    "ui.statusline.insert" = { fg = "onTertiary", bg = "tertiary", modifiers = ["bold"] }
    "ui.statusline.select" = { fg = "onSecondary", bg = "secondary", modifiers = ["bold"] }

    "ui.bufferline" = { fg = "onSurface", bg = "surfaceContainerLowest" }
    "ui.bufferline.active" = { fg = "onSurface", bg = "surfaceContainer", underline = { color = "primary", style = "line" } }
    "ui.bufferline.background" = { bg = "surfaceContainerLowest" }

    "ui.popup" = { fg = "onSurface", bg = "surfaceContainerLow" }

    "ui.window" = { fg = "onSurface" }
    "ui.help" = { fg = "onSurface", bg = "surfaceContainerLow" }

    "ui.text" = { fg = "onBackground" }
    "ui.text.focus" = { fg = "onSurface", bg = "surfaceContainer", modifiers = ["bold"] }

    "ui.virtual" = "surfaceVariant"
    "ui.virtual.ruler" = { bg = "surfaceContainerLow" }
    "ui.virtual.indent-guide" = "surfaceVariant"
    "ui.virtual.inlay-hint" = { fg = "onSurfaceVariant", bg = "surfaceContainer", modifiers = ["dim"] }
    "ui.virtual.jump-label" = { fg = "primary", modifiers = ["bold"] }

    "ui.menu" = { fg = "onSurface", bg = "surfaceContainer" }
    "ui.menu.selected" = { fg = "onPrimary", bg = "primary", modifiers = ["bold"] }

    "ui.selection" = { bg = "surfaceContainerHigh" }

    "ui.highlight" = { bg = "primaryContainer", modifiers = ["bold"] }

    "ui.cursorline" = { bg = "surfaceContainerLowest" }
    "ui.cursorline.primary" = { bg = "surfaceContainerLow" }
    "ui.cursorline.secondary" = { bg = "surfaceContainerLow" }

    error = "error"
    warning = "warning"
    info = "info"
    hint = "hint"

    "diagnostic.hint" = { underline = { color = "hint", style = "curl" } }
    "diagnostic.info" = { underline = { color = "info", style = "curl" } }
    "diagnostic.warning" = { underline = { color = "warning", style = "curl" } }
    "diagnostic.error" = { underline = { color = "error", style = "curl" } }
    "diagnostic.unnecessary" = { modifiers = ["dim"] }

    [palette]
    # Constants to be used in syntax highlighting, not meant for template processor.
    warning = "#f9e2af"
    info = "#89dceb"
    hint = "#94e2d5"
    plus = "#a6e3a1"
    delta = "#89b4fa"

    # Base16 slots, kept in the same order and source colors as nvim-base16.lua.
    base00 = "{{colors.surface.default.hex}}"
    base01 = "{{colors.surface_container.default.hex}}"
    base02 = "{{colors.surface_container_high.default.hex}}"
    base03 = "{{colors.outline.default.hex}}"
    base04 = "{{colors.on_surface_variant.default.hex}}"
    base05 = "{{colors.on_surface.default.hex}}"
    base06 = "{{colors.on_surface.default.hex}}"
    base07 = "{{colors.on_background.default.hex}}"
    base08 = "{{colors.error.default.hex}}"
    base09 = "{{colors.tertiary.default.hex}}"
    base0A = "{{colors.secondary.default.hex}}"
    base0B = "{{colors.primary.default.hex}}"
    base0C = "{{colors.tertiary_fixed_dim.default.hex}}"
    base0D = "{{colors.primary_fixed_dim.default.hex}}"
    base0E = "{{colors.secondary_fixed_dim.default.hex}}"
    base0F = "{{colors.error_container.default.hex}}"

    # Template colors
    primary = "{{colors.primary.default.hex}}"
    primaryFixedDim = "{{colors.primary_fixed_dim.default.hex}}"
    surfaceTint = "{{colors.primary.default.hex}}"
    onPrimary = "{{colors.on_primary.default.hex}}"
    primaryContainer = "{{colors.primary_container.default.hex}}"
    onPrimaryContainer = "{{colors.on_primary_container.default.hex}}"

    secondary = "{{colors.secondary.default.hex}}"
    secondaryFixedDim = "{{colors.secondary_fixed_dim.default.hex}}"
    onSecondary = "{{colors.on_secondary.default.hex}}"
    secondaryContainer = "{{colors.secondary_container.default.hex}}"
    onSecondaryContainer = "{{colors.on_secondary_container.default.hex}}"

    tertiary = "{{colors.tertiary.default.hex}}"
    tertiaryFixedDim = "{{colors.tertiary_fixed_dim.default.hex}}"
    onTertiary = "{{colors.on_tertiary.default.hex}}"
    tertiaryContainer = "{{colors.tertiary_container.default.hex}}"
    onTertiaryContainer = "{{colors.on_tertiary_container.default.hex}}"

    error = "{{colors.error.default.hex}}"
    onError = "{{colors.on_error.default.hex}}"
    errorContainer = "{{colors.error_container.default.hex}}"
    onErrorContainer = "{{colors.on_error_container.default.hex}}"

    background = "{{colors.background.default.hex}}"
    onBackground = "{{colors.on_background.default.hex}}"
    surface = "{{colors.surface.default.hex}}"
    onSurface = "{{colors.on_surface.default.hex}}"
    surfaceVariant = "{{colors.surface_variant.default.hex}}"
    onSurfaceVariant = "{{colors.on_surface_variant.default.hex}}"

    outline = "{{colors.outline.default.hex}}"
    outlineVariant = "{{colors.outline_variant.default.hex}}"

    surfaceContainerLowest = "{{colors.surface_container_lowest.default.hex}}"
    surfaceContainerLow = "{{colors.surface_container_low.default.hex}}"
    surfaceContainer = "{{colors.surface_container.default.hex}}"
    surfaceContainerHigh = "{{colors.surface_container_high.default.hex}}"
    surfaceContainerHighest = "{{colors.surface_container_highest.default.hex}}"
  '';
in
{
  userTemplates = {
    templates.helix-theme = {
      input_path = helixThemeTemplate;
      output_path = "~/.config/helix/themes/noctalia.toml";
      post_hook = "pkill -USR1 hx || true";
    };
  };
}
