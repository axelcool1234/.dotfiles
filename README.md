# TODO
- Add cursors back
- Add Grub theme back
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
- Theme related TODOs
  - Glide browser does not start pywalfox automatically. See if there's a fix.
    - Also pywalfox does not look great. See if there are solutions.
  - Neovim's telescope should have rounded text boxes and titles shouldn't have filled backgrounds.
    - Basically telescope needs some management for Noctalia
  - See if Code can change theme dynamically (will have to patch Code)
  - Add themes for MPV and IMV
- https://www.reddit.com/r/niri/comments/1rjrd26/border_color_depending_on_the_current_neovim_mode/
- Steal this: https://github.com/flickowoa/zephyr/issues/1
- Switch to this: https://github.com/niri-wm/niri/pull/3483
- improve some of the import stuff in modules/ to use import-tree when possible
- https://www.reddit.com/r/niri/comments/1mwnoil/niri_run_or_raise_focus_app_rotate_between/
- Look at old dotfiles for `hhx`, aka headless helix.

## Fresh Install
We'll use the `legion` host as an example.

1. Build this flake's installer ISO.
   ```bash
   nix build .#nixosConfigurations.iso.config.system.build.isoImage
   ```
   The resulting ISO will be available under `./result/iso/`.
2. Write that ISO to a USB drive and boot it in UEFI mode.
   You generally do not mount the USB drive for this. Instead, write the ISO
   directly to the whole USB device.
   Example:
   ```bash
   cd /path/to/this/repo

   # Identify the USB drive. Look for the removable disk, for example /dev/sda.
   lsblk

   # If the desktop auto-mounted any partitions on the USB, unmount them first.
   sudo umount /dev/sdX1 2>/dev/null || true
   sudo umount /dev/sdX2 2>/dev/null || true

   # Write the ISO to the whole USB disk, not to a partition such as /dev/sdX1.
   sudo dd \
     if=./result/iso/<image-name>.iso \
     of=/dev/sdX \
     bs=4M \
     status=progress \
     conv=fsync

   sync
   sudo eject /dev/sdX
   ```
   Replace `/dev/sdX` with your actual USB device, and replace
   `<image-name>.iso` with the file under `./result/iso/`.
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