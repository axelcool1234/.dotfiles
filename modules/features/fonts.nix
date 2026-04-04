{
  hostVars,
  lib,
  pkgs,
  ...
}:
let
  cfg = hostVars.fonts;

  resolvePkgsAttr = attrPath:
    builtins.foldl' (acc: name: builtins.getAttr name acc) pkgs attrPath;

  packageAttrPaths = lib.unique (
    builtins.filter (path: path != null) (
      map (fontSpec: fontSpec.packageAttrPath) (builtins.attrValues cfg)
    )
  );

  fontPackages = map resolvePkgsAttr packageAttrPaths;
in
{
  config = {
    fonts.packages = fontPackages;

    fonts.fontconfig.defaultFonts = {
      serif = [ cfg.ui.family ];
      sansSerif = [ cfg.ui.family ];
      monospace = lib.unique [
        cfg.monospace.family
        cfg.symbols.family
      ];
      emoji = [ cfg.emoji.family ];
    };
  };
}
