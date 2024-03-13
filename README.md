# Update Commands
- nix flake update
- sudo nixos-rebuild switch --flake .#default

# Rollback Command
- sudo nixos-rebuild switch --flake .#default --rollback


# Fresh Install
https://nix-community.github.io/home-manager/index.xhtml#sec-install-standalone
- Go to Standalone installation
- Copy the commands for the unstable channel
- To ensure it has been installed correctly, try "man home-configuration.nix"

# Useful NixOS Resources:
- https://mynixos.com/
- https://search.nixos.org/packages
