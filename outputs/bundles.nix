{ inputs, lib, myLib, self, ... }:
let
  # Discover the top-level exported bundles.
  # This collects:
  # - `name.nix`
  # - `name/default.nix`
  #
  # Example output shape:
  # {
  #   foundation = ../modules/bundles/foundation.nix;
  #   workstation = ../modules/bundles/workstation.nix;
  #   ...
  # }
  bundleFiles = myLib.importTree.entries ../modules/bundles;
in
# Import each discovered bundle entrypoint.
#
# Input shape:
# {
#   foundation = ../modules/bundles/foundation.nix;
#   workstation = ../modules/bundles/workstation.nix;
#   ...
# }
#
# Output shape:
# {
#   foundation = <module>;
#   workstation = <module>;
#   ...
# }
lib.mapAttrs (
  # `_name` is the exported bundle name, like `foundation`.
  # We do not use it directly here, so it is prefixed with `_`.
  _name: bundleFile:

  # `bundleFile` is the path for that exported bundle entrypoint.
  # Example values:
  # - ../modules/bundles/foundation.nix
  # - ../modules/bundles/workstation.nix
  import bundleFile {
    inherit self;
  }
) bundleFiles
