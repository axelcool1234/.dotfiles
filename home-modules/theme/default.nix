{
  pkgs,
  lib,
  theme ? null,
  ...
}:
let
  themeData =
    if theme != null then
      theme.lookupThemeData
    else
      _: null;
in
{
  config.xdg.configFile = lib.optionalAttrs (themeData "wallpaper" != null) {
    "dotfiles-theme/wallpaper.png".source = themeData "wallpaper";
  };
}
