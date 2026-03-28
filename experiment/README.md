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

- Sound
  PipeWire / WirePlumber / desktop audio tooling are not set up yet.
- Fonts
  System font packages and default font choices are not wired in yet.
- GTK / Kvantum / cursors / console colors
  General desktop styling and non-theme-adjacent visual integration are missing.
- Theming
  Need to decide whether Noctalia Shell should manage this imperatively, or if
  theming should go back to a declarative model.
- GRUB theme
  Bootloader theming is still missing.
- Screenshots and screen recording
  The old Waybar-era helper workflows are gone, and replacements are still
  needed.

## Additions

These are ideas that go beyond the original dotfiles rather than merely
restoring old behavior.

- Assure that automatic store optimization and garbage collection are set up correctly
- Possibly preserve the old Hyprland + Waybar + Dunst + Rofi + related stack as
  an alternative desktop setup
  One idea: expose wrapper packages like `old-hyprland` and `old-waybar`, where
  `old-waybar` pulls in the rest of the old desktop helper stack.
- NixOS Impermanence
  Also revisit the alternative approach that looked appealing but was forgotten.
- Disko
- Figure out cache servers correctly
  Source: `https://nixos-and-flakes.thiscute.world/nix-store/intro`
- Disable nix channels
  Source: `https://nixos-and-flakes.thiscute.world/best-practices/nix-path-and-flake-registry`
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
