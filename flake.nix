# Flake.nix
{
	description = "Flake Config";

    inputs = {
        nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
        home-manager = {
            url = "github:nix-community/home-manager/master";
            inputs.nixpkgs.follows = "nixpkgs";
        };
        hyprland.url = "github:hyprwm/Hyprland";
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
                ];
            };
        };

		# List of user configurations
        homeConfigurations = {
            # Main user
            axelcool1234 = home-manager.lib.homeManagerConfiguration {
                inherit pkgs;
                modules = [
                 ./hosts/Legion-Laptop/home.nix 
                 ./home-modules
                ];
            };
        };
    };
}
