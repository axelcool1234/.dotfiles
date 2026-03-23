{ lib }:
let
  # Internal library layers used to implement the public theme API.
  constructors = import ./constructors.nix { inherit lib; };
  internal = import ./internal.nix { inherit lib; };
  resolvers = import ./resolvers.nix { inherit lib; };
in
{
  stylix = import ./stylix.nix {
    inherit constructors lib;
  };

  # Public API: enrich a plain theme bundle with runtime helper methods.
  # Inputs:
  # - theme: attrset, plain theme bundle from one family
  # Output:
  # - attrset, runtime theme bundle with accessor/resolver conveniences and mode flags
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

      sourceType =
        if theme != null && theme ? source && theme.source ? type then
          theme.source.type
        else
          null;
    in
    theme
    // accessors
    // {
      sourceType = sourceType;
      isFamily = sourceType == "family";
      isStylix = sourceType == "stylix";
      # Check whether one app/provider should be treated as Stylix-owned for this runtime theme.
      # Inputs:
      # - input: string app key, provider attrset, or null provider value
      # Output:
      # - bool
      isHandledByStylix = input:
        let
          provider = resolveInput input;
        in
        sourceType == "stylix"
        && provider == null;
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
