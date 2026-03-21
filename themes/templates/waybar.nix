{ lib, theme }:
let
  paletteNames = import ../palette-names.nix;
  appPaletteNames = builtins.filter (name: !(lib.hasPrefix "helix." name)) paletteNames;
in
lib.concatStringsSep "\n"
  (map (name: "@define-color ${name} ${theme.hex name};") appPaletteNames)
