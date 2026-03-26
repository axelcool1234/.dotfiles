{
  lib,
  pkgs,
  selfPkgs,
  wlib,
  ...
}:
{
  imports = [ wlib.wrapperModules.niri ];

  config.settings = {
    spawn-at-startup = [
      (lib.getExe selfPkgs.noctalia-shell)
    ];

    binds = { };

    xwayland-satellite.path = lib.getExe pkgs.xwayland-satellite;
  };
}
