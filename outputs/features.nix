{ self, inputs, lib, myLib, ... }:
let
  # Discover only the top-level exported features.
  # This collects:
  # - `name.nix`
  # - `name/default.nix`
  #
  # It does not recurse into private implementation helpers such as
  # `desktop/niri.nix`, only the entrypoints (`default.nix`) are exported.
  featureFiles = myLib.collectImmediateModules ../modules/features;
in
# Build the exported `self.features` attrset.
#
# Input shape:
# {
#   desktop = ../modules/features/desktop;
#   environment = ../modules/features/environment.nix;
#   ...
# }
#
# Output shape:
# {
#   desktop = <module function>;
#   environment = <module function>;
#   ...
# }
lib.mapAttrs (
  # `_name` is the exported feature name, like `desktop`.
  # We do not use it directly here, so it is prefixed with `_`.

  # `featureFile` is the path for that exported feature entrypoint.
  # Example values:
  # - ../modules/features/desktop
  # - ../modules/features/environment.nix
  _name: featureFile:

  # `moduleArgs` is the argument set that the NixOS module system passes in when
  # it evaluates this feature later (by `lib.nixosSystem`).
  #
  # Important values inside `moduleArgs` include:
  # - `config`: the merged module configuration
  # - `options`: the declared options
  # - `lib`: nixpkgs lib
  # - `pkgs`: package set for the current system
  # - your `specialArgs`
  moduleArgs@{
    pkgs,
    selfPkgs ? self.packages.${pkgs.stdenv.hostPlatform.system},
    ...
  }:

  # Import the feature file and extend the arguments with repo-specific values
  # like `selfPkgs`. `selfPkgs` is the package set for the current system and host,
  # for example `self.packages.x86_64-linux` and `"fermi"`.
  import featureFile (
    moduleArgs
    // {
      inherit self;
      inherit selfPkgs;
    }
  )
) featureFiles
