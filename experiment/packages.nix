{ self, inputs }:
let
  lib = inputs.nixpkgs.lib;
  myLib = import ./lib { inherit lib; };

  # In lieu of flake-parts
  systems = [
    "aarch64-darwin"
    "aarch64-linux"
    "x86_64-darwin"
    "x86_64-linux"
  ];
  forAllSystems =
    apply:
    lib.genAttrs systems (
      system:
      apply {
        inherit system;
        pkgs = import inputs.nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
      }
    );

  wrapperModules = myLib.collectNamedNixFiles ./wrappers;
  directPackages = myLib.collectNamedNixFiles ./pkgs;
in
forAllSystems (
  { pkgs, ... }:
  let
    wrappedPackages = lib.mapAttrs (
      _name: module:
      (inputs.wrapper-modules.lib.evalModules {
        modules = [ module ];
        specialArgs = {
          inherit self inputs;
        };
      }).config.wrap
        { inherit pkgs; }
    ) wrapperModules;
    importedPackages = lib.mapAttrs (
      _name: packageFile:
      import packageFile {
        inherit
          self
          inputs
          pkgs
          lib
          ;
      }
    ) directPackages;
  in
  wrappedPackages
  // importedPackages
)
