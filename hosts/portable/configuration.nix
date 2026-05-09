{ lib, ... }:
{
  imports = [ ./impermanence.nix ];

  boot.initrd.availableKernelModules = [
    "nvme"
    "sd_mod"
    "thunderbolt"
    "uas"
    "usb_storage"
    "usbhid"
    "xhci_pci"
  ];

  boot.loader = {
    efi.canTouchEfiVariables = lib.mkForce false;
    grub = {
      efiInstallAsRemovable = true;
      useOSProber = lib.mkForce false;
    };
  };

  hardware.enableRedistributableFirmware = true;
  hardware.cpu.amd.updateMicrocode = lib.mkDefault true;
  hardware.cpu.intel.updateMicrocode = lib.mkDefault true;
}
