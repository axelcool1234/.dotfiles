{ inputs, myLib, ... }:
myLib.forAllSystems inputs (
  { pkgs, ... }:
  {
    default = pkgs.mkShell {
      packages = [
        pkgs.nil
        pkgs.lua-language-server
      ];
    };
  }
)
