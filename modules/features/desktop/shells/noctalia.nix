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
    # Keep the login keyring password synchronized when the account password is
    # changed through `passwd`, not only when the keyring is unlocked at login.
    security.pam.services.passwd.enableGnomeKeyring = true;

    programs.noctalia = {
      enable = true;
      package = selfPkgs.noctalia;
      systemd.enable = true;
      recommendedServices.enable = true;
    };
  };
}
