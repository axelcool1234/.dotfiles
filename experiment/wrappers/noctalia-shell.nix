{
  lib,
  pkgs,
  self,
  wlib,
  ...
}:
let
  useNoctaliaTheme = self.defaults.desktop-shell == "noctalia-shell";

  activeTemplateIds = [
    "gtk"
    "qt"
    "discord"
    "pywalfox"
    "spicetify"
    "kitty"
    "zathura"
    "yazi"
    "helix"
    "btop"
  ];

  activeTemplates = map (id: {
    inherit id;
    enabled = true;
  }) activeTemplateIds;
in
{
  imports = [ wlib.wrapperModules.noctalia-shell ];

  config = {
    package = pkgs.noctalia-shell;

    settings = {
      templates = lib.mkIf useNoctaliaTheme {
        enableUserTheming = true;
        activeTemplates = activeTemplates;
      };
    };
  };
}
