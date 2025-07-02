{
  description = "Development shell for FoundryVTT using nix-foundryvtt";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    foundryvtt.url = "github:reckenrode/nix-foundryvtt";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, foundryvtt, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };

        # You can pick a different version here
        fvtt = foundryvtt.packages.${system}.foundryvtt_13;

      in {
        devShell = pkgs.mkShell {
          name = "foundryvtt-dev";
          packages = [
            fvtt
            pkgs.haguichi
            pkgs.logmein-hamachi
          ];
        };
      }
    );
}
