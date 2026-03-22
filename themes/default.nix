{ lib }:
let
  # Internal library layers used to implement the public theme API.
  constructors = import ./constructors.nix { inherit lib; };
  internal = import ./internal.nix { inherit lib; };
  resolvers = import ./resolvers.nix { inherit lib; };
in
{
  # Public API: enrich a plain theme bundle with runtime helper methods.
  # Inputs:
  # - theme: attrset, plain theme bundle from one family
  # Output:
  # - attrset, runtime theme bundle with accessor and resolver conveniences attached
  withRuntime = theme:
    let
      accessors = import ./accessors.nix {
        inherit internal resolvers theme;
      };

      resolveInput = input:
        if builtins.isString input then
          accessors.providerFor input
        else
          input;
    in
    theme
    // accessors
    // {
      resolveAssetSource = input: resolvers.resolveAssetSource (resolveInput input);
      resolveWrapperText = input: resolvers.resolveWrapperText (resolveInput input);
    };

  # Public API: available theme families.
  # Output:
  # - attrset mapping family ids to family builder APIs
  families = import ./families {
    inherit constructors internal lib;
  };
}
