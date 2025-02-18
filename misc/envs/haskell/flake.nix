{
  description = "Haskell Env";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
    flake-utils.url = "github:numtide/flake-utils";
  }; 

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs { inherit system; };
        myHaskellEnv = pkgs.haskellPackages.ghcWithHoogle (haskellPackages: with haskellPackages; [ 
            random 
            haskell-language-server 
        ]);
      in
      with pkgs; {
        devShells.default = mkShell {
          buildInputs = [
            myHaskellEnv
          ];
          shellHook = ''
            export HELIX_RUNTIME="$PWD/runtime"
          '';
        };
      }
    );
}
