{ self, inputs }:
let
  lib = inputs.nixpkgs.lib;

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
in
forAllSystems (
  { pkgs, system }:
  let
    selfPkgs = self.packages.${system};

    watchedPackageNames = [
      "fish"
      "git"
      "glide-browser"
      "helix"
      "yazi"
    ];

    watchedPackages = map (name: selfPkgs.${name}) watchedPackageNames;
  in
  {
    default = pkgs.mkShell {
      packages = [
        pkgs.direnv
        pkgs.lorri
      ] ++ watchedPackages;

      shellHook = ''
        export FLAKE_PATH="$PWD"
      '';
    };
  }
)
