# Flake.nix
{
	description = "Flake Config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
      home-manager = {
        url = "github:nix-community/home-manager/master";
        inputs.nixpkgs.follows = "nixpkgs";
      };
      # hyprland.url = "github:hyprwm/Hyprland";
      # See: https://github.com/wez/wezterm/issues/5255
      hyprland.url = "github:hyprwm/Hyprland/c198d744b77f272c2fc187eb6d431580a99ab6c3";
      spicetify-nix.url = "github:the-argus/spicetify-nix";
      foundryvtt.url = "github:reckenrode/nix-foundryvtt";
    };

	outputs = { self, nixpkgs, home-manager, ... }@inputs:
	let
	  system = "x86_64-linux";
	  pkgs = nixpkgs.legacyPackages.${system};
	in
	{

	# List of system configurations
    nixosConfigurations = {
      # Default config
      default = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/Legion-Laptop/configuration.nix
          ./nixos-modules
        ];
      };

      # Foundry VTT Server
      foundry = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = [
            ./hosts/foundry/configuration.nix
            inputs.foundryvtt.nixosModules.foundryvtt
          ];
      };
    };

    # List of user configurations
    homeConfigurations = {
      # Main user
      axelcool1234 = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = { inherit inputs; };
        modules = [
         ./hosts/Legion-Laptop/home.nix 
         ./home-modules
        ];
      };
    };
  };
}
