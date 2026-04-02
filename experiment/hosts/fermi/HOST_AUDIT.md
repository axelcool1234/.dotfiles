# Fermi Host Audit

Audit date: `2026-04-01`

This file records the current live hardware facts for `fermi`, the parts of this
repo that intentionally manage the host, and the small set of things worth
remembering if the machine changes later.

Unlike `legion`, this host does not currently need a dedicated handwritten
hardware policy layer. The existing host entry stays intentionally small, with
most board-specific behavior now delegated to the upstream `nixos-hardware`
profile for this motherboard family.

## Verdict

`Small update applied`

The current `fermi` host setup is appropriately minimal:

- [`configuration.nix`](./configuration.nix) now imports the upstream
  `nixos-hardware` ASUS X570-E profile, then the generated hardware scan plus
  host-local firewall and impermanence scaffolding.
- Live hardware is booting cleanly without any special vendor-specific module in
  this repo beyond the upstream board profile.
- The NVIDIA card is currently running on `nouveau`, and the evaluated config is
  not trying to force a proprietary NVIDIA policy.

The main caveat now is that the live system is still the old pre-wipe ext4
install, while the repo has been updated to target a Disko-managed btrfs
impermanence reinstall.

## Live Host Profile

### Identity

- Hostname: `fermi`
- Vendor string: `System manufacturer`
- Product string: `System Product Name`
- Board vendor: `ASUSTeK COMPUTER INC.`
- Board name: `ROG STRIX X570-E GAMING`
- Board revision: `Rev X.0x`
- BIOS version seen during this audit: `4021`

### Software State

- Kernel: `6.18.18`
- NixOS version: `26.05.20260318.b40629e (Yarara)`
- Evaluated toplevel drvPath:
  `/nix/store/m2w8qb69lilf7p8fmfld3xgkb30k1wyn-nixos-system-fermi-26.05.20260328.8110df5.drv`

### CPU and Memory

- CPU: `AMD Ryzen 9 5950X 16-Core Processor`
- Topology: `32` logical CPUs, `16` cores, `1` socket
- Virtualization: `AMD-V`
- RAM seen during audit: `131807056 kB` (`~125.7 GiB`)

### Graphics

- GPU: `NVIDIA TU117GL [T600]`
- PCI address: `0000:0a:00.0`
- Live kernel driver: `nouveau`
- DRM nodes present:
  - `card0`
  - `card0-DP-1`
  - `card0-DP-2`
  - `card0-DP-3`
  - `card0-DP-4`
  - `renderD128`
- `nvidia-smi` was not available during the audit, which is consistent with the
  current non-proprietary NVIDIA setup.

### Storage

- NVMe system disk: `INTEL SSDPEKNW020T8` (`1.9T`)
  - EFI partition: `512M` mounted at `/boot`
  - Root / store partition: `1.7T` `ext4` mounted at `/` and `/nix/store`
  - Swap partition: `138.3G`
- Additional SATA disk: `ST8000DM004-2CX188` (`7.3T`)
  - Single `ext4` partition present on `sda1`

### Networking

- Ethernet: `Realtek RTL8125 2.5GbE` on `enp5s0`
- Ethernet: `Intel I211 Gigabit` on `enp6s0`
- Wi-Fi: `Intel Wi-Fi 6 AX200` on `wlp4s0`
- Interface state seen during the audit:
  - `enp5s0` up
  - `enp6s0` down
  - `wlp4s0` down

## What The Repo Currently Manages

The `fermi` host entry is currently composed of:

- [`configuration.nix`](./configuration.nix)
- [`hardware-configuration.nix`](./hardware-configuration.nix)
- [`firewall.nix`](./firewall.nix)
- [`impermanence.nix`](./impermanence.nix)

It now also imports:

- `inputs.nixos-hardware.nixosModules.asus-rog-strix-x570e`

Key evaluated facts from this flake:

- `hardware.enableAllFirmware = true`
- `boot.kernelModules = [ "atkbd" "btintel" "ctr" "kvm-amd" "loop" "nct6775" "zenpower" ]`
- `boot.initrd.availableKernelModules` includes the expected storage and USB
  drivers for this machine
- `services.xserver.videoDrivers = [ "modesetting" "fbdev" ]`
- `networking.firewall.enable = true`
- `networking.nftables.enable = true`
- The host-specific nftables ruleset allows:
  - loopback traffic
  - established and related traffic
  - SSH only from `155.98.65.56` and `155.98.65.57`
- `preferences.impermanence.enable = true`
- `preferences.impermanence.diskDevice = "/dev/disk/by-id/nvme-INTEL_SSDPEKNW020T8_PHNH117201DB2P0C"`
- `preferences.impermanence.swapSize = "128G"`
- `preferences.impermanence.btrfsDevice = "/dev/disk/by-partlabel/disk-main-nixos"`

This matches the intended design: keep the host definition primitive, but let
Disko and impermanence describe the post-wipe storage layout explicitly.

## Findings

### 1. No dedicated handwritten host hardware module is currently required

There is no evidence from the live system that `fermi` needs a `drivers.nix`-
style file similar to `legion`.

Why:

- The machine is already booting and evaluating cleanly with the generated
  hardware scan and a small amount of host-local policy.
- There is no hybrid GPU story, firmware GPU mode switch, or laptop-specific
  platform control layer that would justify a larger custom module.
- The live setup is using the generic display stack rather than a custom NVIDIA
  policy.
- Importing the upstream board module is enough to cover the obvious X570-E-
  specific tweaks without growing a new local hardware policy file.

### 2. The upstream `nixos-hardware` profile is now the right default here

There is now a `nixos-hardware` profile for this motherboard family:

- `asus/rog-strix/x570e`

At the time of this audit, that upstream module mainly provides:

- common AMD CPU defaults
- AMD pstate / zenpower-related imports
- common SSD support
- explicit `btintel` and `nct6775` kernel modules

This is now imported directly by [`configuration.nix`](./configuration.nix).
That is a reasonable low-risk improvement because it centralizes board-specific
defaults upstream instead of forcing this repo to rediscover them later.

What this buys us immediately:

- explicit `btintel` loading for the AX200 Bluetooth side
- explicit `nct6775` loading for board sensor support
- explicit `zenpower` support for Zen-family monitoring / telemetry
- the upstream AMD CPU / SSD profile stack for this board family

When to reconsider whether it is still the right import:

- Bluetooth or board-sensor behavior regresses after rebuild
- CPU power-management behavior becomes a tuning target
- future rebuilds show a hardware regression that the upstream module already
  handles

### 3. Fermi is now configured for a wipe-and-reinstall impermanence layout

[`impermanence.nix`](./impermanence.nix) is no longer placeholder-only.

It now targets:

- the real NVMe disk by stable by-id path
- a `128G` swap partition, matching the host's installed RAM capacity
- a btrfs root expected at `/dev/disk/by-partlabel/disk-main-nixos`

[`hardware-configuration.nix`](./hardware-configuration.nix) also no longer
describes the old ext4 root, EFI, and swap devices, which is the same pattern
already used on `legion` for Disko-managed installs.

Important distinction:

- the live machine facts recorded earlier in this document still describe the
  old install that was on disk during the audit
- the evaluated NixOS configuration now describes the intended post-wipe layout

## Re-Audit Triggers

Re-check this host if any of the following changes happen:

- you switch from `nouveau` to the proprietary NVIDIA driver or need CUDA
- you finish the wipe/install and want the document refreshed against the new
  live btrfs layout
- you start depending on motherboard sensors, fan control, or Bluetooth quirks
- the motherboard, GPU, storage topology, or BIOS setup changes materially

## Evidence Collected

The audit was based on the live host plus flake evaluation.

Commands used:

```bash
hostname
uname -r
nixos-version
lscpu
grep MemTotal /proc/meminfo
lsblk -o NAME,MODEL,SIZE,TYPE,FSTYPE,MOUNTPOINTS
lspci -D -d ::03xx
lspci -nnk
ip -brief link
ls -1 /sys/class/drm
cat /proc/cmdline
cat /sys/devices/virtual/dmi/id/product_name
cat /sys/devices/virtual/dmi/id/sys_vendor
cat /sys/devices/virtual/dmi/id/board_vendor
cat /sys/devices/virtual/dmi/id/board_name
cat /sys/devices/virtual/dmi/id/board_version
cat /sys/devices/virtual/dmi/id/bios_version
nix eval --json .#nixosConfigurations.fermi.config.hardware.enableAllFirmware
nix eval --json .#nixosConfigurations.fermi.config.boot.kernelModules
nix eval --json .#nixosConfigurations.fermi.config.boot.initrd.availableKernelModules
nix eval --json .#nixosConfigurations.fermi.config.services.xserver.videoDrivers
nix eval --json .#nixosConfigurations.fermi.config.networking.firewall.enable
nix eval --json .#nixosConfigurations.fermi.config.networking.nftables.enable
nix eval --raw .#nixosConfigurations.fermi.config.networking.nftables.ruleset
nix eval --json .#nixosConfigurations.fermi.config.preferences.impermanence.enable
nix eval --json .#nixosConfigurations.fermi.config.preferences.impermanence.diskDevice
nix eval --json .#nixosConfigurations.fermi.config.preferences.impermanence.swapSize
nix eval --json .#nixosConfigurations.fermi.config.preferences.impermanence.btrfsDevice
nix eval --raw .#nixosConfigurations.fermi.config.system.build.toplevel.drvPath
```

## Sources

Local sources:

- [`configuration.nix`](./configuration.nix)
- [`hardware-configuration.nix`](./hardware-configuration.nix)
- [`firewall.nix`](./firewall.nix)
- [`impermanence.nix`](./impermanence.nix)
- [`../../outputs/nixosConfigurations.nix`](../../outputs/nixosConfigurations.nix)

External source checked during this audit:

- `nixos-hardware` ASUS ROG Strix X570-E profile:
  `https://github.com/NixOS/nixos-hardware/blob/master/asus/rog-strix/x570e/default.nix`
