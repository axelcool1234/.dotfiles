# Experiment

This is the experimental rewrite of the main dotfiles.

Current direction:
- move from Hyprland to Niri
- move away from Home Manager for the main desktop stack
- use wrappers as the primary application/config packaging layer
- use Noctalia Shell instead of the old Waybar + Dunst + Rofi + related stack

This file tracks feature parity gaps and future improvements so the migration has
an explicit checklist.

## Feature Parity

These are the missing or regressed pieces that should be addressed before this
experiment can fully replace the old dotfiles.

- Fonts
  System font packages and default font choices are not wired in yet.
- GTK / Kvantum / cursors / console colors
  General desktop styling and non-theme-adjacent visual integration are missing.
- GRUB theme
  Bootloader theming is still missing.
- Screenshots and screen recording
  The old Waybar-era helper workflows are gone, and replacements are still
  needed.
- Niri binds

## Additions

These are ideas that go beyond the original dotfiles rather than merely
restoring old behavior.

- Assure that automatic store optimization and garbage collection are set up correctly
- Figure out cache servers correctly
  Source: `https://nixos-and-flakes.thiscute.world/nix-store/intro`
- GitHub CI
  Include flake integrity checks and possibly NixOS tests.
  Source: `https://nixos-and-flakes.thiscute.world/other-usage-of-flakes/testing`
- Figure out `direnv` + `lorri` and add the needed support for local development
- Explore `nix-portable`, `nix-appimage`, and `railpack` for portability
- Improve Kitty
  - Scratchpads
  - Motion that yanks filepaths and urls
  - Look into whether or not a Tmux vim mode where you can move around is possible, or
    if CTRL+SHIFT+E to explore the scrollback is all we can do
- Explore possibly throwing out the greeter and autologin into the lockscreen instead
- Niri + Noctalia configuration and bindings
  - wlr-which-key
- Switch from PCManFM to just yazi + ripgdrag

### Minor Theme-related TODOs
- Glide browser does not start pywalfox automatically. See if there's a fix.
- Neovim's telescope should have rounded text boxes and titles shouldn't have filled backgrounds.
  - Basically telescope needs some management for Noctalia
- See if Code can change theme dynamically (will have to patch Code)
- Add themes for MPV and IMV

## Intentional Changes

These are not regressions.

- Hyprland is being replaced with Niri.
- Home Manager is being replaced by wrappers for the main desktop setup.
- Noctalia Shell is replacing the old Waybar / Dunst / Rofi-oriented setup.
- Thunar is being replaced by PCManFM.
- `jujutsu` is being dropped.
- `starship` is being dropped.
- Automatic store optimization and garbage collection were removed on purpose
  for now and should only come back after being designed properly.

## Legion Fresh Install

Current intended install path for `legion`:

1. Build this flake's installer ISO.
   ```bash
   nix build .#nixosConfigurations.iso.config.system.build.isoImage
   ```
   The resulting ISO will be available under `./result/iso/`.
2. Write that ISO to a USB drive and boot it in UEFI mode.
3. Get networking working in the live environment.
4. Clone this repo in the live environment.
   Example:
   ```bash
   sudo -i
   git clone <repo-url> /tmp/dotfiles
   cd /tmp/dotfiles
   ```
5. Use the installer helper package command (recommended).
   ```bash
   disko-install legion
   ```
6. If you want manual control instead, build the plain `legion` system plus its Disko script.
   ```bash
   nix build \
     .#nixosConfigurations.legion.config.system.build.toplevel \
     .#nixosConfigurations.legion.config.system.build.diskoScript \
     --out-link /tmp/dotfiles/result-legion-toplevel
   ```
7. Partition, format, and mount the Linux disk.
   ```bash
   sudo -i
   umount -R /mnt/disko-install-root 2>/dev/null || true
   umount -R /mnt 2>/dev/null || true
   swapoff -a 2>/dev/null || true

   /tmp/dotfiles/result-legion-toplevel-1
   ```
8. Install the already-built `legion` system directly.
   ```bash
   nixos-install \
     --no-channel-copy \
     --no-root-password \
     --system /tmp/dotfiles/result-legion-toplevel \
     --root /mnt
   ```
9. Reboot into the new system.
10. Keep the flake checkout at `~/.dotfiles` and rebuild from there.
   Example:
   ```bash
   sudo nixos-rebuild switch --flake ~/.dotfiles#legion
   ```

Notes:
- The installer ISO target lives at `nixosConfigurations.iso` and is meant to be
  used as the bootstrap environment for fresh installs.
- `legion` is a UEFI install and should keep `boot.loader.grub.device = "nodev"`.
  GRUB should install into the EFI System Partition at `/boot`, not to the whole
  NVMe disk as a BIOS/MBR bootloader.
- Do not use upstream `disko-install` for this host as-is. Its installer wrapper
  forces a disk GRUB target during `nixos-install`, which overrides the repo's
  EFI-only GRUB setup and can trigger the `Installing for i386-pc platform.`
  failure.
- `~/.dotfiles` is persisted by default in the impermanence module so the flake
  checkout survives reboots.
- Legion's old ext4 root, boot, and swap entries were removed from
  `hosts/legion/hardware-configuration.nix` so Disko is the intended storage
  source of truth for the fresh install.
