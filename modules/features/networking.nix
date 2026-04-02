{ lib, hostVars, baseVars, ... }:
{
  networking = {
    networkmanager.enable = true;
    hostName = hostVars.hostName;
  };

  users.users.${baseVars.username}.extraGroups = [ "networkmanager" ];

  preferences.impermanence.persist.systemDirectories = lib.mkAfter [
    "/etc/NetworkManager/system-connections"
  ];

  preferences.impermanence.persist.homeDirectories = lib.mkAfter [
    { directory = ".local/share/keyrings"; mode = "0700"; }
  ];
}
