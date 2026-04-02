{ ... }:
{
  preferences.impermanence = {
    # If we disable this, make sure to regenerate hardware-configuration.nix
    # so that it manages the filesystem instead of Disko. We would also need
    # to run the NixOS graphical installer instead of our custom ISO installer,
    # so that it can wipe the disk.
    enable = true;

    # Primary Linux/NixOS disk for Fermi.
    diskDevice = "/dev/disk/by-id/nvme-INTEL_SSDPEKNW020T8_PHNH117201DB2P0C";

    # Match the host's installed RAM capacity for hibernation-friendly swap.
    swapSize = "128G";

    # Expected btrfs root partition path after the Disko layout is applied.
    btrfsDevice = "/dev/disk/by-partlabel/disk-main-nixos";
  };
}
