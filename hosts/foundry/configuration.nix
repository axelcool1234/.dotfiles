{ inputs, pkgs, ... }:
{
  imports =
  [ # Include the results of the hardware scan.
    ./hardware-configuration.nix
  ];
  
  services.foundryvtt = {
    enable = false;
    hostName = "<hostname goes here>";
    minifyStaticFiles = true;
    package = inputs.foundryvtt.packages.${pkgs.system}.foundryvtt_12; # Sets the version to the latest FoundryVTT v12.
    proxyPort = 443;
    proxySSL = true;
    upnp = false;
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.05"; # Did you read the comment?
}
