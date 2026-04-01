{ config, inputs, lib, ... }:
let
  cfg = config.preferences.impermanence;
  efiMountPoint = config.preferences.grub.efiSysMountPoint;
in
{
  # Pull in Disko's NixOS module.
  #
  # Disko extends the normal NixOS module system with `disko.devices.*` options.
  # Those options describe disks, partitions, filesystems, subvolumes, and mount
  # points declaratively.
  imports = [ inputs.disko.nixosModules.disko ];

  # Only activate this layout when the host explicitly opts in.
  config = lib.mkIf cfg.enable {
    # Disko starts from `disko.devices`.
    #
    # Here we define one physical disk called `main`. The attribute name `main`
    # is arbitrary; it is just our label inside the Nix config. The real target
    # device is chosen by the `device = ...` line below.
    disko.devices.disk.main = {
      # This tells Disko that `main` is a real block device such as an NVMe SSD,
      # not an LVM volume, mdraid array, loopback image, and so on.
      type = "disk";

      # Which physical disk to operate on.
      #
      # We use a stable `/dev/disk/by-id/...` path rather than `/dev/nvme1n1`
      # because kernel device numbering can change. The by-id path is tied to the
      # actual hardware identity of the SSD.
      device = cfg.diskDevice;

      # `content` describes what lives *inside* this disk.
      #
      # For a normal UEFI machine, the first layer is the partition table. Here we
      # choose GPT because that is the modern UEFI-friendly partition scheme.
      content = {
        type = "gpt";

        # `partitions` is the set of partitions that will be created inside the
        # GPT partition table.
        #
        # This host wants three partitions:
        # 1. EFI System Partition for the bootloader
        # 2. swap partition, sized to RAM for easy hibernation support
        # 3. one big Btrfs partition for the actual NixOS system state
        partitions = {
          ESP = {
            # `name` becomes the GPT partition label.
            #
            # This is mainly for human clarity. Tools like `lsblk` and `/dev/disk`
            # helpers can show it, which makes the layout easier to inspect.
            name = "boot";

            # Small EFI System Partition size.
            #
            # This is where GRUB's UEFI files live. It does *not* contain your
            # whole Linux system, only firmware-readable boot files.
            size = cfg.bootPartitionSize;

            # GPT type code for an EFI System Partition.
            #
            # Disko uses the same GUID/type-code idea you would set manually with
            # partitioning tools. `EF00` is the standard UEFI ESP code.
            type = "EF00";

            # `content` now describes what lives *inside this partition*.
            #
            # The ESP is a simple FAT filesystem because UEFI firmware expects a
            # firmware-readable filesystem here.
            content = {
              type = "filesystem";

              # FAT is required here for compatibility with UEFI firmware.
              format = "vfat";

              # NixOS mounts the ESP at the path chosen by the GRUB feature.
              #
              # That matches the GRUB feature module, which installs the EFI
              # bootloader files into that same mount point.
              mountpoint = efiMountPoint;

              # Restrict permissions on the mounted FAT filesystem.
              #
              # VFAT has no Unix permissions of its own, so mount options are how
              # we keep the boot partition from being world-readable.
              mountOptions = [ "umask=0077" ];
            };
          };

          swap = {
            # GPT partition label for the swap partition.
            name = "swap";

            # Swap is sized to RAM on this host because the goal is to keep the
            # hibernation path straightforward.
            size = cfg.swapSize;

            # This partition is not mounted like a normal filesystem.
            # Instead, the kernel uses it as swap space.
            content = {
              type = "swap";

              # Tell Disko/NixOS that this swap device should be considered the
              # resume target for hibernation.
              #
              # In practice, this means the generated system knows which swap
              # device to look at when resuming a hibernated system image.
              resumeDevice = true;
            };
          };

          root = {
            # GPT partition label for the large Linux data partition.
            #
            # Later, the impermanence rollback code refers to the resulting block
            # device using `/dev/disk/by-partlabel/nixos`.
            name = "nixos";

            # Use the rest of the disk after EFI and swap.
            size = "100%";

            # The final partition is a Btrfs filesystem.
            #
            # Btrfs is doing two jobs here:
            # - it stores the real system data
            # - it gives us subvolumes, which make impermanence practical
            content = {
              type = "btrfs";

              # Force filesystem creation if the partition already contains old
              # metadata from a previous install.
              #
              # This is convenient during planned reinstalls, but it is also why
              # this config should only be applied to the disk you truly intend to
              # wipe.
              extraArgs = [ "-f" ];

              # Btrfs subvolumes let one filesystem behave like several logical
              # trees with different mount points.
              #
              # This is the core of the impermanence setup:
              # - `root` becomes the live `/`
              # - `nix` stays persistent at `/nix`
              # - `persist` stores the explicitly preserved state
              subvolumes = {
                ${cfg.rootSubvolume} = {
                  # The subvolume mounted as the real root filesystem.
                  #
                  # Impermanence later rotates this subvolume into `old_roots` on
                  # boot and creates a new empty one in its place.
                  mountpoint = "/";

                  # Shared Btrfs mount options such as `compress=zstd:1` and
                  # `noatime` come from the impermanence preferences module.
                  mountOptions = cfg.mountOptions;
                };

                ${cfg.nixSubvolume} = {
                  # Persistent Nix store and system generations.
                  #
                  # `/nix` must *not* be ephemeral, because NixOS boot entries and
                  # system closures live there.
                  mountpoint = "/nix";
                  mountOptions = cfg.mountOptions;
                };

                ${cfg.persistenceSubvolume} = {
                  # Explicitly preserved state.
                  #
                  # The impermanence module bind-mounts selected files and
                  # directories into the ephemeral root from here.
                  mountpoint = cfg.persistenceRoot;
                  mountOptions = cfg.mountOptions;
                };
              }
              # Optional persistent `/home`.
              #
              # In the current design this usually stays null, meaning home is
              # treated as ephemeral-by-default and only selected paths are
              # persisted. But the option is here so the layout can evolve later
              # without rewriting the whole file.
              // lib.optionalAttrs (cfg.homeSubvolume != null) {
                ${cfg.homeSubvolume} = {
                  mountpoint = "/home";
                  mountOptions = cfg.mountOptions;
                };
              };
            };
          };
        };
      };
    };

    # Make these mounts available early in boot.
    #
    # This matters because the impermanence logic expects the persistent backing
    # storage to exist before it starts wiring preserved files and directories
    # into the ephemeral root.
    fileSystems."/".neededForBoot = true;
    fileSystems."/nix".neededForBoot = true;
    fileSystems.${cfg.persistenceRoot}.neededForBoot = true;
  };
}
