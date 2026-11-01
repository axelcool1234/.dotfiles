{
  selfPkgs,
  baseVars,
  ...
}:
{
  environment.shells = [ "/run/current-system/sw/bin/fish" ];

  environment.systemPackages = [
    selfPkgs.environment
  ];

  # Keep the passwd entry on the stable system-profile path and register it in
  # /etc/shells. In addition to normal login-shell checks, pkexec rejects a
  # session whose SHELL is not listed there.
  users.users.${baseVars.username}.shell = "/run/current-system/sw/bin/fish";
}
