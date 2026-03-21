{ lib, helpers }:
{
  catppuccin = import ./catppuccin.nix {
    inherit lib helpers;
  };
}
