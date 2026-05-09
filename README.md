# TODO
- Add cursors back
- Add Grub theme back
- Steal features from: https://noctalia.dev/plugins/screen-toolkit/
- Replace recorder script with: https://noctalia.dev/plugins/screen-recorder/
- Get calendar: https://noctalia.dev/plugins/weekly-calendar/
- Get colorscheme creator: https://noctalia.dev/plugins/color-scheme-creator/
- Get keybind cheatsheet: https://noctalia.dev/plugins/keybind-cheatsheet/
- Get: https://noctalia.dev/plugins/privacy-indicator/
- Get: https://noctalia.dev/plugins/fancy-audiovisualizer/
- Get: https://noctalia.dev/plugins/unicode-picker/
- Get: https://noctalia.dev/plugins/kaomoji-provider/
- Get: https://noctalia.dev/plugins/file-search/
- Get (for fun): https://noctalia.dev/plugins/activate-linux/
- Investigate: https://noctalia.dev/plugins/assistant-panel/
- Configure mime types for files
- Add .face back to get a profile picture for noctalia-shell
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
  - Neovim's telescope should have rounded text boxes and titles shouldn't have filled backgrounds.
    - Basically telescope needs some management for Noctalia
  - See if Code can change theme dynamically (will have to patch Code)
  - Add themes for MPV and IMV
- https://www.reddit.com/r/niri/comments/1rjrd26/border_color_depending_on_the_current_neovim_mode/
- Steal this: https://github.com/flickowoa/zephyr/issues/1
- Switch to this: https://github.com/niri-wm/niri/pull/3483
- https://www.reddit.com/r/niri/comments/1mwnoil/niri_run_or_raise_focus_app_rotate_between/
- Look at old dotfiles for `hhx`, aka headless helix.
- Overhaul README
  - Table of contents
  - Showcase (pictures and video)
  - Defaults section (what editor, terminal, desktop, desktop shell, etc. am I using?)
  - Steal from old README
  - TODO for .dotfiles section at the bottom
  - TODO for personal forks (like Helix) at the bottom
- Consider recreating my website
  - Pure HTML, CSS, and whatever shiny things interest me (like pretext)
    - Mozilla HTML docs
  - Create a custom landing page for Firefox but for fun put it on the website.
  - Notes? Could place all these TODO stuff in there maybe.
  - Could also journal work I'm doing each day - may be a good way to stay organized?
- NVim Helix motions:
  - Optional: Possibly render a pair being selected when doing `mr<char>`?
  - Optional: Make `x` work how I prefer: when cursor is at the top, `x` extends upwards. When it's at the bottom, `x` extends downwards.
  - Optional: Try and figure out how to have `/` match live while typing
  - Optional: `<space>?` - maybe command palette?
  - Optional: Implement flash jump.
  - Optional: Implement DAP stuff (overseer, neotest)
    - Implement `miT`/`maT` and `[T`/`]T`.
  - Optional: Look into quickfix list (vim thing)
  - Optional: Look into location list (vim thing)
  - Optional: Look into marks (vim thing)
  - Optional: Look into overview (vim thing)
  - Not sure if possible: Implement `|`, `<A-|>`, `!`, `<A-!>`, `$`
  - Refer to Helix's static-cmd.md for better naming of functions for our helix motion library.
  - Figure out whichkey situation
    - `<Space>`
      - `<Space>w`
    - `z`
    - `<C-W>`
    - `"`
  - Multicursor backspace in insert mode only works on the primary cursor for some reason
  - `<C-Space>` should work when typing a command.
  - Note for ACTUAL Helix: `"a/` and then some text lets you search via `n` and `N` and assigns register `a` such contents.
    Then, when you select some text and do `s` then some text, the `/` register is assigned said contents. However, the active
    search register is seemingly unchanged, so `n` and `N` moves the primary cursor to the contents from register `a`. Not sure
    if this is intended, but it is not how I have it implemented in Neovim. 
  - Decide whether to stick to Helix's case insensitive regex or Neovim's case sensitive regex
  - We should work on unbinding as much of default nvim stuff as possible.
  - Reorganize `<space>w` and `ctrl+w` to match Helix more closely
  - `mdm` kills multiple cursors

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
  used as the install environment for fresh installs.
- `legion` is a UEFI install and should keep `boot.loader.grub.device = "nodev"`.
  GRUB should install into the EFI System Partition at `/boot`, not to the whole
  NVMe disk as a BIOS/MBR bootloader.
- Do not use upstream `disko-install` for this host as-is. Its installer wrapper
  forces a disk GRUB target during `nixos-install`, which overrides the repo's
  EFI-only GRUB setup and can trigger the `Installing for i386-pc platform.`
  failure.
- `~/.dotfiles` is persisted by default in the impermanence module so the flake
  checkout survives reboots.

## Portable Host

`nixosConfigurations.portable` is the external-SSD host profile. It avoids a
host-local `hardware-configuration.nix` so the install stays more movable.

Notes:
- The current `portable` host targets `/dev/disk/by-id/usb-WD_Elements_2620_575848324532304443364350-0:0`.
- It currently uses the `foundation` bundle plus GRUB and a small manual tool set, including Neovim.
- It installs GRUB as a removable EFI target and does not try to write firmware boot entries.
- Build it with `nix build .#nixosConfigurations.portable.config.system.build.toplevel`.
- Build the Disko script with `nix build .#nixosConfigurations.portable.config.system.build.diskoScript`.
- The ISO helper supports `disko-install portable`.
- The installer helper is also exposed as the flake package `.#disko-install`, so from any NixOS environment you can run `nix run .#disko-install -- portable`.
