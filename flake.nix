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

    # Machine-specific hardware modules and sane defaults for known laptops.
    nixos-hardware = {
      url = "github:NixOS/nixos-hardware/master";
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

    # Glide Browser
    glide = {
      url = "github:glide-browser/glide.nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    # Modded Helix
    modded-helix = {
      url = "github:axelcool1234/helix/modded";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Stylix
    stylix = {
      url = "github:nix-community/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # LLM Agents
    llm-agents.url = "github:numtide/llm-agents.nix";
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
      themeLib = import ./themes { lib = nixpkgs.lib; };

      # Import nixpkgs for one system with this repo's common package config.
      # Inputs:
      # - nixpkgsInput: flake input, nixpkgs source to import
      # - system: string, target system
      # Output:
      # - attrset, package set for the target system
      mkPkgs = nixpkgsInput: system:
        import nixpkgsInput {
          inherit system;
          config.allowUnfree = true;
          config.allowUnfreePredicate = (_: true);
        };

      # Build the runtime theme bundle for one nixpkgs/system pair.
      # Inputs:
      # - nixpkgsInput: flake input, nixpkgs source to import
      # - system: string, target system
      # Output:
      # - attrset, runtime theme bundle
      mkTheme = nixpkgsInput: system:
        let
          pkgs = mkPkgs nixpkgsInput system;
        in
        import ./themes/selected_theme.nix { inherit themeLib pkgs; };

      # Build one NixOS system configuration.
      # Inputs:
      # - nixpkgsInput: flake input, nixpkgs source to import
      # - system: string, target system
      # - username: string, primary user name
      # - hostname: string, target host name
      # - desktop: string, selected desktop/session id
      # Output:
      # - attrset, nixosSystem result
      mkSystem =
        nixpkgsInput: system: username: hostname: desktop:
        let
          theme = mkTheme nixpkgsInput system;
        in
        nixpkgsInput.lib.nixosSystem {
          system = system;
          specialArgs = {
            inherit inputs username hostname desktop theme;
          };
          modules = [
            { networking.hostName = hostname; }
            ./hosts/${hostname}/configuration.nix
            ./nixos-modules
          ] ++ nixpkgs.lib.optionals theme.isStylix [
            inputs.stylix.nixosModules.stylix
            (themeLib.stylix.nixosModule theme)
          ];
        };

      # Build one Home Manager configuration.
      # Inputs:
      # - nixpkgsInput: flake input, nixpkgs source to import
      # - system: string, target system
      # - username: string, primary user name
      # - hostname: string, target host name
      # - desktop: string, selected desktop/session id
      # Output:
      # - attrset, homeManagerConfiguration result
      mkHome =
        nixpkgsInput: system: username: hostname: desktop:
        let
          theme = mkTheme nixpkgsInput system;
        in
        home-manager.lib.homeManagerConfiguration {
          pkgs = mkPkgs nixpkgsInput system;
          extraSpecialArgs = {
            inherit inputs username hostname desktop theme;
          };
          modules = [
            {
              # Some imported Home Manager modules consult nixpkgs.config
              # even when pkgs is provided explicitly.
              nixpkgs.config.allowUnfree = true;
              nixpkgs.config.allowUnfreePredicate = (_: true);

              # Basic info home-manager needs
              home.username = username;
              home.homeDirectory = "/home/${username}";
              home.stateVersion = "23.11"; # Please read https://home-manager-options.extranix.com/?query=home.stateVersion before changing.
              programs.home-manager.enable = true;
            }
            ./home.nix
          ] ++ nixpkgs.lib.optionals theme.isStylix [
            inputs.stylix.homeModules.stylix
            (themeLib.stylix.nixosModule theme)
          ];
        };
    in
    {
      nixosConfigurations = {
        #                    pkgs         Architecture     Username    Hostname  Desktop
        legion = mkSystem inputs.nixpkgs "x86_64-linux" "axelcool1234" "legion" "hyprland";
        fermi = mkSystem inputs.nixpkgs "x86_64-linux" "axelcool1234" "fermi" "hyprland";
      };
      homeConfigurations = {
        #                                 pkgs         Architecture     Username    Hostname  Desktop
        "axelcool1234@legion" = mkHome inputs.nixpkgs "x86_64-linux" "axelcool1234" "legion" "hyprland";
        "axelcool1234@fermi" = mkHome inputs.nixpkgs "x86_64-linux" "axelcool1234" "fermi" "hyprland";
      };
    };
}
