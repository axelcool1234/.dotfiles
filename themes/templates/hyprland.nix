{ lib, theme }:
let
  paletteNames = import ../palette-names.nix;
  appPaletteNames = builtins.filter (name: !(lib.hasPrefix "helix." name)) paletteNames;

  hyprlandColors =
    lib.concatStringsSep "\n\n"
      (map (name: ''
        ${"$" + name} = rgb(${theme.palette.${name}})
        ${"$" + name}Alpha = ${theme.palette.${name}}
      '') appPaletteNames);
in
''
  ${hyprlandColors}

  env = HYPRCURSOR_THEME,${theme.cursor.name}
  env = HYPRCURSOR_SIZE,${toString theme.cursor.size}
  env = XCURSOR_THEME,${theme.cursor.name}
  env = XCURSOR_SIZE,${toString theme.cursor.size}
''
