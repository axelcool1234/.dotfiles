let
  catppuccin = import ./catppuccin.nix;
in
catppuccin.mkTheme {
  flavor = "mocha";
  accent = "teal";
  wallpaper = ../wallpapers/nixos-catppuccin.png;
}
