{
  description = "OCaml Env";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  }; 

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs { inherit system; };
      in
      with pkgs; {
        devShells.default = mkShell {
          buildInputs = [
            ocaml
            dune_3
            z3
            ocamlPackages.utop
            ocamlPackages.ocaml-lsp
            ocamlPackages.ocamlformat

            ocamlPackages.zarith
            ocamlPackages.ounit
            ocamlPackages.z3
          ];
          shellHook = ''
            export HELIX_RUNTIME="$PWD/runtime"
          '';
        };
      }
    );
}
