# Flake.nix
{
  description = "Flake Config";

  inputs = {
    # NixOS
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-25-05.url = "github:NixOS/nixpkgs/nixos-25.05";

    # Home-manager
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Hyprland
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
      # NixOS Configuration
      mkSystem =
        pkgs: system: username: hostname:
        pkgs.lib.nixosSystem {
          system = system;
          specialArgs = { inherit inputs username hostname; };
          modules = [
            { networking.hostName = hostname; }
            ./hosts/${hostname}/configuration.nix
            ./nixos-modules
          ];
        };

      # Home Manager Configuaration
      mkHome =
        pkgs: system: username: hostname:
        home-manager.lib.homeManagerConfiguration {
          pkgs = pkgs.legacyPackages.${system};
          extraSpecialArgs = { inherit inputs username hostname; };
          modules = [
            ./home.nix
            ./home-modules
          ];
        };
    in
    {
      nixosConfigurations = {
        #                    pkgs         Architecture     Username    Hostname
        legion = mkSystem inputs.nixpkgs "x86_64-linux" "axelcool1234" "legion";
        fermi = mkSystem inputs.nixpkgs "x86_64-linux" "axelcool1234" "fermi";
      };
      homeConfigurations = {
        #                                 pkgs         Architecture     Username    Hostname
        "axelcool1234@legion" = mkHome inputs.nixpkgs "x86_64-linux" "axelcool1234" "legion";
        "axelcool1234@fermi" = mkHome inputs.nixpkgs "x86_64-linux" "axelcool1234" "fermi";
      };
    };
}
