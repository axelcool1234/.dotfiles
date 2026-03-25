{ hostVars, baseVars, ... }:

{
  networking = {
    networkmanager.enable = true;
    hostName = hostVars.hostName;
  };
  users.users.${baseVars.username}.extraGroups = [ "networkmanager" ];
}
