{ config, lib, ... }:
let
  cfg = config.preferences.grub;
in
{
  options.preferences.grub = {
    # Repo-local source of truth for the EFI System Partition mount point.
    #
    # NixOS already exposes `boot.loader.efi.efiSysMountPoint`, but keeping a
    # custom option here makes it easy for other repo modules to reference the
    # same value without duplicating a literal like `/boot`.
    efiSysMountPoint = lib.mkOption {
      type = lib.types.str;
      default = "/boot";
      description = "Mount point for the EFI System Partition used by the GRUB feature.";
    };
  };

  config.boot.loader = {
    efi = {
      # Mount point for the EFI System Partition (ESP).
      # This is where GRUB's EFI files are installed.
      efiSysMountPoint = cfg.efiSysMountPoint;

      # Allow NixOS to update EFI boot entries in firmware.
      # Needed on most normal UEFI installs.
      canTouchEfiVariables = true;
    };

    grub = {
      # Use GRUB as the bootloader.
      enable = true;

      # Build/install the EFI GRUB target instead of a BIOS/MBR setup.
      efiSupport = true;

      # Detect other operating systems and add them to the GRUB menu.
      # Useful for dual-boot setups.
      useOSProber = true;

      # No block device install target for pure EFI setups.
      # GRUB is installed into the EFI partition instead.
      device = "nodev";
    };
  };
}
