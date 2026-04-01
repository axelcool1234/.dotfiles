{ self, ... }:
{
  imports = [ self.features.impermanence ];

  preferences.impermanence = {
    # If we disable this, make sure to regenerate hardware-configuration.nix
    # so that it manages the filesystem instead of Disko.
    enable = true;

    # Current Linux/NixOS disk on this Legion. The other NVMe is for Windows.
    diskDevice = "/dev/disk/by-id/nvme-Micron_MTFDKBA1T0TFH_221837417A35";

    swapSize = "32G";

    # Expected btrfs root partition path after the Disko layout is applied.
    btrfsDevice = "/dev/disk/by-partlabel/nixos";
  };
}
