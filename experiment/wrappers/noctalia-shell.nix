{
  lib,
  pkgs,
  self,
  wlib,
  ...
}:
let
  useNoctaliaTheme = self.defaults.desktop-shell == "noctalia-shell";
in
{
  imports = [ wlib.wrapperModules.noctalia-shell ];

  config = {
    package = pkgs.noctalia-shell;

    settings = {
      templates = lib.mkIf useNoctaliaTheme {
        enableUserTheming = true;
        gtk = true;
        qt = true;
        discord = true;
        pywalfox = true;
        spicetify = true;
        kitty = true;
        yazi = true;
        btop = true;
      };
    };
  };
}
