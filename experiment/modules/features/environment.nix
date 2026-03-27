{
  lib,
  selfPkgs,
  baseVars,
  ...
}:
{
  environment.systemPackages = [
    selfPkgs.environment
  ];

  users.users.${baseVars.username}.shell = lib.getExe selfPkgs.environment;
}
