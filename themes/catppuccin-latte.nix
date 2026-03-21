let
  catppuccin = import ./catppuccin.nix;
in
catppuccin.mkTheme {
  flavor = "latte";
  accent = "teal";
  wallpaper = ../wallpapers/nixos-catppuccin.png;
}
