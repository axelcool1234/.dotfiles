{ lib }:
let
  helpers = import ./lib.nix { inherit lib; };
in
{
  inherit helpers;

  families = import ./families {
    inherit lib helpers;
  };
}
