{
  description = "Python Environment";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  }; 

  outputs = { self, nixpkgs, ... }: 
  let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
  in
  {
    devShells.x86_64-linux.default = pkgs.mkShell {
      nativeBuildInputs = with pkgs; [
        python3
        basedpyright
        ruff
      ];
      propagatedBuildInputs = with pkgs.python313Packages; [
        pip
        z3-solver
        setuptools
      ];
      shellHook = ''
        export HELIX_RUNTIME="$PWD/runtime"
      '';
    };
  };
}
