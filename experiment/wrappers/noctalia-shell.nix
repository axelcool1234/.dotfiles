{ wlib, pkgs, ... }:
{
  imports = [ wlib.wrapperModules.noctalia-shell ];

  config = {
    package = pkgs.noctalia-shell;

    settings.templates = {
      enableUserTheming = true;
      gtk = true;
      qt = true;
      discord = true;
      pywalfox = true;
    };
  };
}
