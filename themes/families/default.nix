{ constructors, internal, lib }:
{
  catppuccin = import ./catppuccin.nix {
    inherit constructors internal lib;
  };

  tokyonight = import ./tokyonight.nix {
    inherit constructors internal lib;
  };
}
