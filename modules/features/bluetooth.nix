{ lib, ... }:
{
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = false;
  };

  preferences.impermanence.persist.systemDirectories = lib.mkAfter [
    "/var/lib/bluetooth"
  ];
}
