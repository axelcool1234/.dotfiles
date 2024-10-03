{
  description = "Python Environment";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
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
        pyright
      ];
      propagatedBuildInputs = with pkgs.python311Packages; [
        pip
      ];
      shellHook = ''
        export HELIX_RUNTIME="$PWD/runtime"
      '';
    };
  };
}
