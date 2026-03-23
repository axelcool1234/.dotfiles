{ lib }:
let
  # Internal library layers used to implement the public theme API.
  constructors = import ./constructors.nix { inherit lib; };
  internal = import ./internal.nix { inherit lib; };
  runtime = import ./runtime.nix {
    inherit internal lib;
  };
in
{
  # Public API: enrich a plain theme bundle with runtime helper methods.
  # Inputs:
  # - theme: attrset, plain theme bundle from one family
  # Output:
  # - attrset, runtime theme bundle with accessor/resolver conveniences and mode flags
  withRuntime = runtime.withRuntime;

  # Public API: available theme families.
  # Output:
  # - attrset mapping family ids to family builder APIs
  families = import ./families {
    inherit constructors internal lib;
  };

  # Public API: Stylix-backed theme bundle builder and companion module helpers.
  # Output:
  # - attrset exposing `mk`, `meta`, and Stylix integration helpers
  stylix = import ./stylix.nix {
    inherit constructors lib;
  };
}
