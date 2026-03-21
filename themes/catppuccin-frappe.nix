let
  catppuccin = import ./catppuccin.nix;
in
catppuccin.mkTheme {
  flavor = "frappe";
  accent = "teal";
  wallpaper = ../wallpapers/nixos-catppuccin.png;
}
