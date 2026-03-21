{ lib, helpers }:
{
  catppuccin = import ./catppuccin.nix {
    inherit lib helpers;
  };

  tokyonight = import ./tokyonight.nix {
    inherit lib helpers;
  };
}
