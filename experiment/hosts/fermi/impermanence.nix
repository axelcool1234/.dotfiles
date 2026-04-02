{ ... }:
{
  preferences.impermanence = {
    # Keep the scaffold inactive until the real wipe/install pass.
    enable = false;

    # Replace this with the actual stable disk identifier you want to target when
    # the Fermi layout is finalized.
    diskDevice = "/dev/disk/by-id/REPLACE-FERMI-DISK";

    # Intended real-host layout: EFI + swap + btrfs, with swap sized to RAM.
    # Replace this with Fermi's actual RAM size when you decide the final layout.
    swapSize = "8G";

    # Fill this in once the final runtime btrfs device path is known.
    btrfsDevice = null;
  };
}
