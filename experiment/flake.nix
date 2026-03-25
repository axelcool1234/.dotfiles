{
  description = "Flake Config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    wrappers.url = "github:Lassulus/wrappers";
    wrapper-modules.url = "github:BirdeeHub/nix-wrapper-modules";

    modded-helix = {
      url = "github:axelcool1234/helix/modded";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self, ... }@inputs:
    {
      packages = import ./packages.nix { inherit self inputs; };
      nixosConfigurations = import ./nixosConfigurations.nix { inherit self inputs; };
    };
}
