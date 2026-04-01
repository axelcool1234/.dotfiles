{ inputs, lib, modulesPath, pkgs, self, ... }:
let
  selfPkgs = self.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  imports = [
    # Build an official-style installer ISO as the base image.
    (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix")
  ];

  # Keep the installer practical for the intended flow:
  # boot the ISO, get online, clone the repo, and run disko-install.
  environment.systemPackages = [
    selfPkgs.git
    inputs.disko.packages.${pkgs.stdenv.hostPlatform.system}.default
    selfPkgs.helix
    pkgs.tmux
  ];

  # Fast to build, reasonable for an installer image.
  isoImage.squashfsCompression = "gzip -Xcompression-level 1";
}
