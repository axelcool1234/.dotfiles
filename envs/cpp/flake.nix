{
  description = "C++ Environment";

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
        bear
        clang-tools
        # Nix shells actually start with "stdenv" which
        # includes tools such as gcc, make, etc.
        # gnumake
        gdb
        nasm
      ];
    shellHook = ''
      export HELIX_RUNTIME="$PWD/runtime"
    '';
    };
  };
}
