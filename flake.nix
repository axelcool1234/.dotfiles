# Flake.nix
{
  description = "Flake Config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-25-05.url = "github:NixOS/nixpkgs/nixos-25.05";
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

    # Spotify
    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Discord
    nixcord = {
      url = "github:kaylorben/nixcord";
    };

    # Helix with modified jump motion
    jump-helix = {
      url = "github:axelcool1234/helix/my-jump";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-25-05,
      home-manager,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      # Home Manager configuaration
      mkHome =
        username: host:
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          extraSpecialArgs = { inherit inputs username host; };
          modules = [
            ./hosts/Legion-Laptop/home.nix
            ./home-modules
          ];
        };
    in
    {

      # List of system configurations
      nixosConfigurations = {
        # Lenovo Legion config
        legion = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = [
            ./hosts/Legion-Laptop/configuration.nix
            ./nixos-modules
          ];
        };

        # Lab config
        fermi = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = [
            ./hosts/fermi/configuration.nix
            ./nixos-modules
          ];
        };
      };

      # List of user configurations
      homeConfigurations = {
        # Main user
        "axelcool1234@fermi" = mkHome "axelcool1234" "fermi";
        "axelcool1234@legion" = mkHome "axelcool1234" "legion";
      };
    };
}
