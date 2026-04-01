{ config, lib, pkgs, ... }:
let
  cfg = config.preferences.impermanence;
in
{
  config = lib.mkIf cfg.enable {
    boot.supportedFilesystems = [ "btrfs" ];

    boot.initrd.postResumeCommands = lib.mkAfter ''
      mkdir -p /btrfs_tmp
      mount -o subvol=/ ${cfg.btrfsDevice} /btrfs_tmp

      if [[ -e /btrfs_tmp/${cfg.rootSubvolume} ]]; then
        mkdir -p /btrfs_tmp/${cfg.oldRootsDirectory}
        timestamp=$(${pkgs.coreutils}/bin/date \
          --date="@$(${pkgs.coreutils}/bin/stat -c %Y /btrfs_tmp/${cfg.rootSubvolume})" \
          "+%Y-%m-%d_%H:%M:%S")
        mv \
          /btrfs_tmp/${cfg.rootSubvolume} \
          /btrfs_tmp/${cfg.oldRootsDirectory}/$timestamp
      fi

      delete_subvolume_recursively() {
        IFS=$'\n'
        for subvolume in $(${pkgs.btrfs-progs}/bin/btrfs subvolume list -o "$1" | cut -f 9- -d ' '); do
          delete_subvolume_recursively "/btrfs_tmp/$subvolume"
        done
        ${pkgs.btrfs-progs}/bin/btrfs subvolume delete "$1"
      }

      if [[ -d /btrfs_tmp/${cfg.oldRootsDirectory} ]]; then
        for archived_root in $(${pkgs.findutils}/bin/find \
          /btrfs_tmp/${cfg.oldRootsDirectory} \
          -maxdepth 1 \
          -mindepth 1 \
          -mtime +${toString cfg.oldRootsRetentionDays}); do
          delete_subvolume_recursively "$archived_root"
        done
      fi

      ${pkgs.btrfs-progs}/bin/btrfs subvolume create /btrfs_tmp/${cfg.rootSubvolume}

      umount /btrfs_tmp
    '';
  };
}
