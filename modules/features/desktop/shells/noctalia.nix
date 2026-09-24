{
  hostVars,
  inputs,
  lib,
  selfPkgs,
  ...
}:
{
  imports = [ inputs.noctalia.nixosModules.default ];

  config = lib.mkIf (hostVars.desktopShell == "noctalia") {
    programs.noctalia = {
      enable = true;
      package = selfPkgs.noctalia;
      systemd.enable = true;
      recommendedServices.enable = true;
    };
  };
}
