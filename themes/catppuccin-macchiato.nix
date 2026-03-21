let
  catppuccin = import ./catppuccin.nix;
in
catppuccin.mkTheme {
  flavor = "macchiato";
  accent = "teal";
  wallpaper = ../wallpapers/nixos-catppuccin.png;
}
