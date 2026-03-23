{ lib, pkgs, theme, ... }:
let
  resolvePkgsAttr = attrPath:
    builtins.foldl' (acc: name: builtins.getAttr name acc) pkgs attrPath;

  themeFonts = theme.requireThemeData "fonts";
  fontPackages =
    lib.unique (
      map resolvePkgsAttr (
        builtins.filter (attrPath: attrPath != null) (
          map (
            fontSpec:
            if builtins.isAttrs fontSpec && fontSpec ? packageAttrPath then fontSpec.packageAttrPath else null
          ) (builtins.attrValues themeFonts)
        )
      )
    );
in
{
  # Fonts
  fonts.packages = fontPackages;
}
