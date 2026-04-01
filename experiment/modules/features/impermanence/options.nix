{
  baseVars,
  inputs,
  lib,
  ...
}:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  imports = [ inputs.impermanence.nixosModules.impermanence ];

  options.preferences.impermanence = {
    enable = mkEnableOption "the btrfs + impermanence scaffold";

    user = mkOption {
      type = types.str;
      default = baseVars.username;
      description = "Primary user whose home persistence should be managed.";
    };

    persistenceRoot = mkOption {
      type = types.str;
      default = "/persist";
      description = "Mountpoint used for impermanence-managed persistent state.";
    };

    diskDevice = mkOption {
      type = with types; nullOr str;
      default = null;
      example = "/dev/disk/by-id/nvme-SERIAL";
      description = "Disko target disk for this host.";
    };

    btrfsDevice = mkOption {
      type = with types; nullOr str;
      default = null;
      example = "/dev/disk/by-partlabel/nixos";
      description = "Btrfs block device mounted in initrd for root rotation operations.";
    };

    bootPartitionSize = mkOption {
      type = types.str;
      default = "1G";
      description = "EFI system partition size used by the Disko scaffold.";
    };

    swapSize = mkOption {
      type = with types; nullOr str;
      default = null;
      example = "8G";
      description = "Optional swap partition size for the Disko scaffold.";
    };

    mountOptions = mkOption {
      type = with types; listOf str;
      default = [ "compress=zstd:1" "noatime" ];
      description = "Shared mount options for the persistent btrfs subvolumes.";
    };

    rootSubvolume = mkOption {
      type = types.str;
      default = "root";
      description = "Mounted root subvolume that gets rotated on boot.";
    };

    oldRootsDirectory = mkOption {
      type = types.str;
      default = "old_roots";
      description = "Top-level directory where previous root subvolumes are archived.";
    };

    oldRootsRetentionDays = mkOption {
      type = types.int;
      default = 30;
      description = "How many days of archived root snapshots to keep.";
    };

    nixSubvolume = mkOption {
      type = types.str;
      default = "nix";
      description = "Persistent subvolume mounted at /nix.";
    };

    persistenceSubvolume = mkOption {
      type = types.str;
      default = "persist";
      description = "Persistent subvolume mounted at the impermanence root.";
    };

    homeSubvolume = mkOption {
      type = with types; nullOr str;
      default = null;
      description = "Optional persistent /home subvolume. Keep null for ephemeral home.";
    };

    persist.systemDirectories = mkOption {
      type = with types; listOf (oneOf [ str attrs ]);
      default = [ ];
      description = "Additional system directories persisted through impermanence.";
    };

    persist.systemFiles = mkOption {
      type = with types; listOf (oneOf [ str attrs ]);
      default = [ ];
      description = "Additional system files persisted through impermanence.";
    };

    persist.homeDirectories = mkOption {
      type = with types; listOf (oneOf [ str attrs ]);
      default = [ ];
      description = "Home directories to persist for the primary user.";
    };

    persist.homeFiles = mkOption {
      type = with types; listOf (oneOf [ str attrs ]);
      default = [ ];
      description = "Home files to persist for the primary user.";
    };
  };
}
