{ ... }:
{
  preferences.impermanence = {
    enable = true;

    # External portable workstation disk currently attached to this system.
    diskDevice = "/dev/disk/by-id/usb-WD_Elements_2620_575848324532304443364350-0:0";

    # Reserve enough swap for the external-SSD host while leaving the rest of
    # the 3.6 TiB disk to btrfs.
    swapSize = "32G";
    resumeFromSwap = false;
  };
}
