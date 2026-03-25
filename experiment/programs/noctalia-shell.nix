{ wlib, pkgs, ... }:
{
  imports = [ wlib.wrapperModules.noctalia-shell ];

  config = {
    package = pkgs.noctalia-shell;
  };
}
