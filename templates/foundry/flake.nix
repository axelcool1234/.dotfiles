{
  description = "Development shell for FoundryVTT using nix-foundryvtt";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    foundryvtt.url = "github:reckenrode/nix-foundryvtt";
  };

  outputs = { nixpkgs, foundryvtt, ... }:
    let
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];
    in
    {
      devShells = nixpkgs.lib.genAttrs systems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };

          fvtt = foundryvtt.packages.${system}.foundryvtt_13;
        in
        {
          default = pkgs.mkShell {
            name = "foundryvtt-dev";
            packages = [
              fvtt
              pkgs.haguichi
              pkgs.logmein-hamachi
            ];
          };
        }
      );
    };
}
