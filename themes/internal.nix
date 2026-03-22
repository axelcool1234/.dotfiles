{ lib }:
let
  # Internal theme helpers used by family implementations and low-level theme logic.
  # These functions operate on theme bundles and palette values. They are not meant to
  # resolve provider files or inspect a selected runtime theme in module code.

  # Hex character lookup used for rgba conversion helpers.
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

  # Convert a two-character hex byte into its integer value.
  # Inputs:
  # - pair: string, two hex characters like "ff"
  # Output:
  # - integer 0..255
  pairToInt = pair:
    (hexDigits.${builtins.substring 0 1 pair} * 16) + hexDigits.${builtins.substring 1 1 pair};

  # Read the shared palette from a theme bundle.
  # Inputs:
  # - themeBundle: attrset|null, theme bundle record
  # Output:
  # - attrset palette
  # - throws if theme.data.palette is missing
  getPalette = themeBundle:
    if themeBundle != null && themeBundle ? data && themeBundle.data ? palette then
      themeBundle.data.palette
    else
      throw "theme.data.palette is required";

  # Normalize palette entries to bare rrggbb hex for internal conversions.
  # Inputs:
  # - color: string, either "#rrggbb" or "rrggbb"
  # Output:
  # - string "rrggbb"
  normalizeHex = color:
    if lib.hasPrefix "#" color then lib.removePrefix "#" color else color;

  # Read one palette color as a CSS rgba() string.
  # Inputs:
  # - themeBundle: attrset, theme bundle carrying data.palette
  # - name: string, palette key
  # - alpha: number, CSS alpha component
  # Output:
  # - string like "rgba(30, 40, 50, 0.7)"
  getRgba = themeBundle: name: alpha:
    let
      color = normalizeHex (getPalette themeBundle).${name};
      red = pairToInt (builtins.substring 0 2 color);
      green = pairToInt (builtins.substring 2 2 color);
      blue = pairToInt (builtins.substring 4 2 color);
    in
    "rgba(${toString red}, ${toString green}, ${toString blue}, ${toString alpha})";

  # Check whether an app entry exists in a theme bundle.
  # Inputs:
  # - themeBundle: attrset|null, theme bundle record
  # - app: string, app key
  # Output:
  # - bool
  hasApp = themeBundle: app:
    themeBundle != null
    && themeBundle ? apps
    && builtins.hasAttr app themeBundle.apps;

  # Check whether an app entry both exists and is enabled.
  # Inputs:
  # - themeBundle: attrset|null, theme bundle record
  # - app: string, app key
  # Output:
  # - bool
  isAppEnabled = themeBundle: app:
    hasApp themeBundle app && themeBundle.apps.${app}.enable;
in
{
  inherit
    getPalette
    getRgba
    hasApp
    isAppEnabled
    pairToInt
    ;
}
