{
  self,
  pkgs,
  baseVars,
  ...
}:
let
  selfPkgs = self.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  imports = [ ./desktop.nix ];

  # Packages
  environment.systemPackages = [
    selfPkgs.environment
  ];

  # User config
  users.users.${baseVars.username}.shell = "${selfPkgs.environment}/bin/fish";
}
