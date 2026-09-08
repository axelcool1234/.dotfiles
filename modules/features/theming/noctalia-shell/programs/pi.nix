{ pkgs, ... }:
let
  # Keep Pi's syntax roles aligned with the Base16 palette.
  # Noctalia rewrites this file whenever the active system color scheme changes;
  # Pi hot reloads the active custom theme without requiring a restart.
  piThemeTemplate = pkgs.writeText "pi-noctalia-theme-template.json" ''
    {
      "$schema": "https://raw.githubusercontent.com/earendil-works/pi/main/packages/coding-agent/src/modes/interactive/theme/theme-schema.json",
      "name": "noctalia",
      "vars": {
        "base00": "{{colors.surface.default.hex}}",
        "base01": "{{colors.surface_container.default.hex}}",
        "base02": "{{colors.surface_container_high.default.hex}}",
        "base03": "{{colors.outline.default.hex}}",
        "base04": "{{colors.on_surface_variant.default.hex}}",
        "base05": "{{colors.on_surface.default.hex}}",
        "base06": "{{colors.on_surface.default.hex}}",
        "base07": "{{colors.on_background.default.hex}}",
        "base08": "{{colors.error.default.hex}}",
        "base09": "{{colors.tertiary.default.hex}}",
        "base0A": "{{colors.secondary.default.hex}}",
        "base0B": "{{colors.primary.default.hex}}",
        "base0C": "{{colors.tertiary_fixed_dim.default.hex}}",
        "base0D": "{{colors.primary_fixed_dim.default.hex}}",
        "base0E": "{{colors.secondary_fixed_dim.default.hex}}",
        "base0F": "{{colors.error_container.default.hex}}",
        "errorContainer": "{{colors.error_container.default.hex}}"
      },
      "colors": {
        "accent": "base0D",
        "border": "base03",
        "borderAccent": "base0D",
        "borderMuted": "base02",
        "success": "base0B",
        "error": "base08",
        "warning": "base0A",
        "muted": "base04",
        "dim": "base03",
        "text": "base05",
        "thinkingText": "base04",

        "selectedBg": "base02",
        "scrollbarThumb": "base02",
        "searchMatchBg": "base02",
        "searchMatchText": "base05",
        "userMessageBg": "base01",
        "userMessageText": "base05",
        "customMessageBg": "base02",
        "customMessageText": "base05",
        "customMessageLabel": "base0E",
        "toolPendingBg": "base01",
        "toolSuccessBg": "base01",
        "toolErrorBg": "errorContainer",
        "toolTitle": "base0D",
        "toolOutput": "base05",

        "mdHeading": "base0A",
        "mdLink": "base0D",
        "mdLinkUrl": "base04",
        "mdCode": "base0B",
        "mdCodeBlock": "base05",
        "mdCodeBlockBorder": "base03",
        "mdQuote": "base04",
        "mdQuoteBorder": "base03",
        "mdHr": "base03",
        "mdListBullet": "base0D",

        "toolDiffAdded": "base0B",
        "toolDiffRemoved": "base08",
        "toolDiffContext": "base04",

        "syntaxComment": "base03",
        "syntaxKeyword": "base0E",
        "syntaxFunction": "base0D",
        "syntaxVariable": "base08",
        "syntaxString": "base0B",
        "syntaxNumber": "base09",
        "syntaxType": "base0A",
        "syntaxOperator": "base05",
        "syntaxPunctuation": "base04",

        "thinkingOff": "base03",
        "thinkingMinimal": "base04",
        "thinkingLow": "base0D",
        "thinkingMedium": "base0C",
        "thinkingHigh": "base0E",
        "thinkingXhigh": "base08",
        "thinkingMax": "base0F",

        "bashMode": "base0D"
      },
      "export": {
        "pageBg": "{{colors.surface.default.hex}}",
        "cardBg": "{{colors.surface_container.default.hex}}",
        "infoBg": "{{colors.surface_container_high.default.hex}}"
      }
    }
  '';
in
{
  userTemplates = {
    templates.pi = {
      input_path = piThemeTemplate;
      output_path = "~/.pi/agent/themes/noctalia.json";
    };
  };
}
