{ lib, pkgs, ... }:
{
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  systemd.services.bluetooth-unblock = {
    description = "Unblock Bluetooth rfkill before BlueZ starts";
    after = [ "systemd-rfkill.service" ];
    before = [ "bluetooth.service" ];
    wantedBy = [ "bluetooth.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${lib.getExe' pkgs.util-linux "rfkill"} unblock bluetooth";
    };
  };

  preferences.impermanence.persist.systemDirectories = lib.mkAfter [
    "/var/lib/bluetooth"
  ];
}
