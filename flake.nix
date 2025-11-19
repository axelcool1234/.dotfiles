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

    # Nix index
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
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

    # Modded Helix
    modded-helix = {
      url = "github:axelcool1234/helix/modded";
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
            {
              # Allows home-manager to manage unfree packages
              nixpkgs.config.allowUnfree = true;
              nixpkgs.config.allowUnfreePredicate = (_: true);

              # Basic info home-manager needs
              home.username = username;
              home.homeDirectory = "/home/${username}";
              home.stateVersion = "23.11"; # Please read https://home-manager-options.extranix.com/?query=home.stateVersion before changing.
              programs.home-manager.enable = true;
            }
            ./home.nix
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
