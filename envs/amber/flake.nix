{
  description = "Amber dev environment with amber-lang and amber-lsp";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        rustPlatform = pkgs.rustPlatform;

        amber-lsp = rustPlatform.buildRustPackage {
          pname = "amber-lsp";
          version = "0.1.16";

          src = pkgs.fetchFromGitHub {
            owner = "amber-lang";
            repo = "amber-lsp";
            rev = "v0.1.16";
            sha256 = "sha256-gozS+ty3vrbBL+biAZRv5wE3nqIGa9hG8Kmz8fa5f+s=";
          };

          cargoHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";

          meta = {
            description = "Amber Language Server";
          };
        };

      in {
        devShells.default = pkgs.mkShell {
          packages = [
            pkgs.amber-lang
            amber-lsp
          ];
        };
      });
}