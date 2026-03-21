{ lib, theme }:
{
  hyprland = import ./hyprland.nix { inherit lib theme; };
  waybar = import ./waybar.nix { inherit lib theme; };
  kitty = import ./kitty.nix { inherit lib theme; };
  wezterm = import ./wezterm.nix { inherit lib theme; };
  helix = import ./helix.nix { inherit lib theme; };
  fish = import ./fish.nix { inherit lib theme; };
  rofi = import ./rofi.nix { inherit lib theme; };
  wlogout = import ./wlogout.nix { inherit lib theme; };
  zathura = import ./zathura.nix { inherit lib theme; };
  nushell = import ./nushell.nix { inherit lib theme; };
  btop = import ./btop.nix { inherit lib theme; };
  discord = import ./discord.nix { inherit lib theme; };
  yazi = import ./yazi.nix { inherit lib theme; };
  yaziSyntectTheme = import ./yazi-syntect-theme.nix { inherit lib theme; };
}
