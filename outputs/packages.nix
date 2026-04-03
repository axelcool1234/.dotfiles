{ defaults, inputs, myLib, ... }:

# Build `self.packages` for every supported system.
#
# The callback below is run once per system, for example:
# - x86_64-linux
# - aarch64-linux
#
# Callback input:
# - `pkgs`: nixpkgs package set for that system
# - `system`: system string for that package set
#
# Callback output:
# - attrset of packages for that one system
# - example shape:
#   {
#     fish = <drv>;
#     kitty = <drv>;
#     environment = <drv>;
#     browser = <drv>;
#     shell = <drv>;
#     window-manager = <drv>;
#   }
myLib.forAllSystems inputs (
  { pkgs, system }:
  let
    # Public flake packages stay host-agnostic on purpose so commands like
    # `nix run .#niri` do not bake in any machine-specific behavior.
    packageSet = myLib.mkPackageSet {
      inherit pkgs system;
      hostVars = defaults // {
        hostName = null;
        stateVersion = null;
      };
    };
  in
  packageSet
  // {
    default = packageSet.vm;
  }
)
