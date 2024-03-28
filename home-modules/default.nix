{ pkgs, lib, ... }: {
  imports = [
    ./gui-programs/wezterm.nix
  ];

  wezterm.enable =
    lib.mkDefault true;
}
