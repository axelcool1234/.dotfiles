{ config, lib, inputs, ... }:
{
  nix = {
    # This will add each flake input as a registry
    # To make nix3 commands consistent with your flake
    registry = lib.mapAttrs (_: value: { flake = value; }) inputs;

    # This will additionally add your inputs to the system's legacy channels
    # Making legacy nix commands consistent as well, awesome!
    nixPath = lib.mapAttrsToList (key: value: "${key}=${value.to.path}") config.nix.registry;

    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      substituters = [
         "https://numtide.cachix.org"
       ];
       trusted-public-keys = [
         "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE="
       ];
    };

  };

  # Remove if you wish to disable unfree packages for your system
  nixpkgs.config.allowUnfree = true;
}
