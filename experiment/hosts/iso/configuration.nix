{ inputs, modulesPath, selfPkgs, pkgs, ... }:
{
  imports = [
    # Build an official-style installer ISO as the base image.
    (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix")
  ];

  environment.systemPackages = [
    inputs.disko.packages.${pkgs.stdenv.hostPlatform.system}.default
    selfPkgs.terminal
    selfPkgs.browser
  ];

  # Fast to build, reasonable for an installer image.
  isoImage.squashfsCompression = "gzip -Xcompression-level 1";
}
