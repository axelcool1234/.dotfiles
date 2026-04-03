# Fermi Host Audit

Audit date: `2026-04-02`

This audit replaces the earlier pre-reinstall snapshot. `fermi` is now on the
new Disko-managed btrfs layout with impermanence enabled.

## Verdict

`Install layout is healthy; login freeze is a kernel VT regression`

Current state in this repo:

- Fermi is configured for `Disko + impermanence`.
- Root is `btrfs` (not ext4).
- The black-screen/freeze after `greetd/tuigreet` login is reproducible as a
  kernel page fault in the VT/console path (`csi_J`), not a storage-layout
  failure.
- Host config now pins Fermi to Linux `6.12` as a mitigation.

## Live Storage Reality (Post-Reinstall)

From `lsblk` on the installer environment against the installed disk:

- Disk: `nvme0n1` (`INTEL SSDPEKNW020T8`)
- Partition labels:
  - `disk-main-boot` (`vfat`, `1G`)
  - `disk-main-swap` (`swap`, `128G`)
  - `disk-main-nixos` (`btrfs`, remaining space)

This matches the intended Disko scaffold and confirms the host is no longer
using the old ext4 root layout.

## Crash Finding (Why Login Freezes)

Persistent journal from the installed system (`/persist/var/log/journal`) shows
the failure shortly after greeting/login handoff:

- Process: `greetd`
- Kernel: `6.18.20`
- Panic signature:
  - `BUG: unable to handle page fault`
  - RIP in `csi_J`
  - stack includes `do_con_write` and `n_tty_write`

Interpretation:

- This is a kernel virtual-console/TTY regression while greetd writes to tty.
- It explains the black screen / freeze.
- It is not evidence that Disko, impermanence, or btrfs is broken.

## Repo State That Matters

`hosts/fermi/configuration.nix` now includes:

- upstream board profile import:
  - `inputs.nixos-hardware.nixosModules.asus-rog-strix-x570e`
- host-local kernel pin:
  - `boot.kernelPackages = pkgs.linuxPackages_6_12;`

The kernel pin is intentionally host-scoped so the rest of the flake can stay
on the normal channel defaults.

## Impermanence / Disko Status

The Fermi host still intentionally uses impermanence:

- `preferences.impermanence.enable = true`
- `preferences.impermanence.diskDevice = /dev/disk/by-id/nvme-INTEL_SSDPEKNW020T8_PHNH117201DB2P0C`
- `preferences.impermanence.btrfsDevice = /dev/disk/by-partlabel/disk-main-nixos`
- `preferences.impermanence.swapSize = "128G"`

No storage misconfiguration was identified that would explain the greetd freeze.

## Known Non-Blocking Issues Seen

- `spotify-flatpak-bootstrap.service` failed in this boot (user service)
- `sshd.service` failed to start repeatedly in this boot

These may still need cleanup, but they are not the root cause of the immediate
login freeze observed here.

## Re-Audit Triggers

Re-audit Fermi when any of the following changes:

- You remove or change the Linux `6.12` pin and test newer kernels again.
- You switch GPU strategy (e.g., proprietary NVIDIA/CUDA policy changes).
- You change Disko partition naming, btrfs subvolume layout, or impermanence
  mount design.
- You replace motherboard/GPU or materially update firmware.

## Evidence Collected

Primary commands used during this update:

```bash
lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,PARTLABEL,MOUNTPOINTS
sudo mount -o subvol=persist /dev/disk/by-partlabel/disk-main-nixos /tmp/fermi-persist
sudo journalctl --directory=/tmp/fermi-persist/var/log/journal --list-boots
sudo journalctl --directory=/tmp/fermi-persist/var/log/journal -b 0 -p 0..4 --no-pager
sudo journalctl --directory=/tmp/fermi-persist/var/log/journal -b 0 --no-pager | rg -i 'greetd|page fault|csi_J|do_con_write'
nix eval --raw .#nixosConfigurations.fermi.config.boot.kernelPackages.kernel.version
```
