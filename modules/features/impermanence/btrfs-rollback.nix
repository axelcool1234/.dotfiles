{ config, lib, pkgs, ... }:
let
  cfg = config.preferences.impermanence;
in
{
  config = lib.mkIf cfg.enable {
    boot.supportedFilesystems = [ "btrfs" ];

    # Newer systemd stage-1 rejects the old shell hook API, so run the same
    # rollback logic as a oneshot service after hibernate-resume handling and
    # before the real root gets mounted at /sysroot.
    boot.initrd.systemd.services.btrfs-rollback-root = {
      requiredBy = [ "sysroot.mount" ];
      before = [
        "sysroot.mount"
        "initrd-root-fs.target"
      ];
      after = [
        "systemd-hibernate-resume.service"
        "initrd-root-device.target"
      ];
      unitConfig.DefaultDependencies = false;
      path = [
        pkgs.btrfs-progs
        pkgs.coreutils
        pkgs.findutils
        pkgs.util-linux
      ];
      serviceConfig.Type = "oneshot";
      script = ''
        btrfs_device=${lib.escapeShellArg cfg.btrfsDevice}
        old_roots_directory=${lib.escapeShellArg cfg.oldRootsDirectory}
        root_subvolume=/btrfs_tmp/root
        old_roots=/btrfs_tmp/$old_roots_directory
        mounted=0

        cleanup() {
          if [[ "$mounted" == 1 ]]; then
            umount /btrfs_tmp || true
          fi
        }
        trap cleanup EXIT

        mkdir -p /btrfs_tmp
        mount -o subvol=/ "$btrfs_device" /btrfs_tmp
        mounted=1

        if [[ -e "$root_subvolume" ]]; then
          mkdir -p "$old_roots"
          timestamp=$(date \
            --date="@$(stat -c %Y "$root_subvolume")" \
            "+%Y-%m-%d_%H:%M:%S")

          archived_root="$old_roots/$timestamp"
          suffix=0
          while [[ -e "$archived_root" ]]; do
            suffix=$((suffix + 1))
            archived_root="$old_roots/$timestamp-$suffix"
          done

          if ! mv "$root_subvolume" "$archived_root"; then
            echo "warning: failed to archive old root subvolume; booting it unchanged" >&2
          fi
        fi

        delete_subvolume_recursively() {
          local target="$1"
          local subvolume

          while IFS= read -r subvolume; do
            [[ -z "$subvolume" ]] && continue
            delete_subvolume_recursively "/btrfs_tmp/$subvolume"
          done < <(btrfs subvolume list -o "$target" | cut -f 9- -d ' ')

          btrfs subvolume delete "$target"
        }

        if [[ -d "$old_roots" ]]; then
          while IFS= read -r -d "" archived_root; do
            if ! btrfs subvolume show "$archived_root" >/dev/null 2>&1; then
              echo "warning: skipping non-subvolume old root: $archived_root" >&2
              continue
            fi

            if ! delete_subvolume_recursively "$archived_root"; then
              echo "warning: failed to delete old root subvolume: $archived_root" >&2
            fi
          done < <(find \
            "$old_roots" \
            -maxdepth 1 \
            -mindepth 1 \
            -mtime +${toString cfg.oldRootsRetentionDays} \
            -print0)
        fi

        if [[ ! -e "$root_subvolume" ]]; then
          btrfs subvolume create "$root_subvolume"
        fi
      '';
    };
  };
}
