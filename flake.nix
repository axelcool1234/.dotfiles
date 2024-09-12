# Flake.nix
{
	description = "Flake Config";

  inputs = {
      nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
      nixpkgs-24-05.url = "github:NixOS/nixpkgs/nixos-24.05";
      home-manager = {
        url = "github:nix-community/home-manager/master";
        inputs.nixpkgs.follows = "nixpkgs";
      };
      # See: https://github.com/hyprwm/Hyprland/issues/5891
      hyprland = {
        type = "git";
        url = "https://github.com/hyprwm/Hyprland";
        submodules = true;
      };
      # See: https://github.com/wez/wezterm/issues/5103#issuecomment-1915820504
      wezterm.url = "github:wez/wezterm?dir=nix";

      # New Fork:
      spicetify-nix = {
        url = "github:Gerg-L/spicetify-nix";
        inputs.nixpkgs.follows = "nixpkgs";
      };

      # Outdated:
      # spicetify-nix.url = "github:the-argus/spicetify-nix";
    };

	outputs = { self, nixpkgs, nixpkgs-24-05, home-manager, ... }@inputs:
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
