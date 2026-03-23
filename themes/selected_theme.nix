{ themeLib, pkgs }:
themeLib.withRuntime (themeLib.stylix.mk {
  source.base16Scheme = "${pkgs.base16-schemes}/share/themes/atlas.yaml";
})
