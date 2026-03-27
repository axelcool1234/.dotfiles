{ inputs, lib, myLib, self, ... }:
let
  # Discover the top-level exported bundles.
  # This collects:
  # - `name.nix`
  # - `name/default.nix`
  #
  # Example output shape:
  # {
  #   foundation = ../modules/bundles/foundation;
  #   workstation = ../modules/bundles/workstation;
  #   ...
  # }
  bundleFiles = myLib.collectImmediateModules ../modules/bundles;
in
# Import each discovered bundle entrypoint.
#
# Input shape:
# {
#   foundation = ../modules/bundles/foundation;
#   workstation = ../modules/bundles/workstation;
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
  # - ../modules/bundles/foundation
  # - ../modules/bundles/workstation
  import bundleFile {
    inherit self;
  }
) bundleFiles
