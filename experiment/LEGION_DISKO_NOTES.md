# Legion Disko / GRUB Notes

## Summary

The `legion` host is configured correctly for a UEFI install.

- Linux disk: `/dev/disk/by-id/nvme-Micron_MTFDKBA1T0TFH_221837417A35`
- Windows disk: `/dev/disk/by-id/nvme-Micron_MTFDKBA1T0TFH_2221382E12E9`
- Boot mode: `UEFI`
- Intended GRUB mode: EFI-only, with `boot.loader.grub.device = "nodev"`

## What Went Wrong

The failure was not caused by the repo-local `legion`, GRUB, or impermanence modules.

The problem came from `disko-install` itself.

Its installer wrapper extends the target NixOS system with:

```nix
boot.loader.grub.devices = lib.mkVMOverride (lib.attrValues diskMappings);
```

That turns a pure UEFI GRUB setup into a disk-based GRUB install during `nixos-install`.
On this machine that produced:

- `Installing for i386-pc platform.`
- BIOS-style install attempt to the whole NVMe disk
- failure because the disk is GPT and has no BIOS Boot Partition

## Why `nodev` Is Correct

For this host, keeping `boot.loader.grub.device = "nodev"` is the right choice.

Reason:

- the machine boots in UEFI mode
- the disk layout uses GPT
- the Linux disk has a proper EFI System Partition mounted at `/boot`
- GRUB should install its EFI files into the ESP instead of trying to write a BIOS bootloader to the whole disk

The repo's GRUB feature is therefore correct.

## Relevant Repo Files

- `modules/features/grub.nix`
- `modules/features/impermanence/default.nix`
- `modules/features/impermanence/options.nix`
- `modules/features/impermanence/btrfs-rollback.nix`
- `hosts/legion/configuration.nix`
- `hosts/legion/impermanence.nix`
- `hosts/legion/disko.nix`

## Repo Observations

### `modules/features/grub.nix`

This is the correct UEFI setup:

- `boot.loader.grub.enable = true`
- `boot.loader.grub.efiSupport = true`
- `boot.loader.grub.device = "nodev"`
- `boot.loader.efi.canTouchEfiVariables = true`

`useOSProber` was changed to `false` to avoid live-USB probing noise during install.

### `modules/features/impermanence/*`

These modules are not causing the GRUB problem.

They provide:

- the target disk option
- the Btrfs device used for rollback logic
- mount options and subvolume names
- persisted directories and files

### `hosts/legion/*`

The `legion` host is also correct.

- `hosts/legion/impermanence.nix` points Disko at the Linux NVMe disk
- `hosts/legion/disko.nix` defines a UEFI-friendly GPT layout
- the ESP is mounted at `/boot`
- the root layout is Btrfs with `root`, `nix`, and `persist` subvolumes

## Working Install Path

Do **not** use `disko-install` for this host as-is, because it overrides GRUB devices.

Use the manual install path instead:

```bash
sudo -i
cd /home/axelcool1234/.dotfiles/experiment

umount -R /mnt/disko-install-root 2>/dev/null || true
umount -R /mnt 2>/dev/null || true
swapoff -a 2>/dev/null || true

nix build \
  .#nixosConfigurations.legion.config.system.build.toplevel \
  .#nixosConfigurations.legion.config.system.build.diskoScript \
  --out-link /home/axelcool1234/.dotfiles/experiment/result-legion-toplevel

/home/axelcool1234/.dotfiles/experiment/result-legion-toplevel-1

nixos-install \
  --no-channel-copy \
  --no-root-password \
  --system /home/axelcool1234/.dotfiles/experiment/result-legion-toplevel \
  --root /mnt
```

## Successful Result

The manual path completed successfully and installed GRUB in the correct mode:

- `installing the GRUB 2 boot loader into /boot...`
- `Installing for x86_64-efi platform.`
- `Installation finished. No error reported.`

After install, firmware showed:

- `NixOS-boot` entry present
- NixOS entry first in boot order
- Windows Boot Manager still present

## Recommendation

Keep the repo's UEFI GRUB `nodev` behavior for `legion`.

If fresh installs should continue using Disko automation, the real long-term fix is to avoid
the `disko-install` GRUB device override for EFI-only systems, or to use the manual Disko +
`nixos-install` path documented above.
