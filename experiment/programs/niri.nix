{
  lib,
  pkgs,
  self,
  wlib,
  ...
}:
{
  imports = [ wlib.wrapperModules.niri ];

  config.settings = {
    spawn-at-startup = [
      (lib.getExe self.packages.${pkgs.stdenv.hostPlatform.system}.noctalia-shell)
    ];

    binds = { };

    xwayland-satellite.path = lib.getExe pkgs.xwayland-satellite;
  };
}
