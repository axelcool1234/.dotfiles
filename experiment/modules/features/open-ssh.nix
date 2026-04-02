{ lib, ... }:
{
  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  preferences.impermanence.persist.systemDirectories = lib.mkAfter [
    "/etc/ssh"
  ];
}
