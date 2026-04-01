{ inputs, modulesPath, lib, self, selfPkgs, pkgs, ... }:
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

  programs.niri = lib.mkIf (self.defaults.desktop-shell == "noctalia-shell") {
    enable = true;
    package = selfPkgs.niri;
  };

  # Fast to build, reasonable for an installer image.
  isoImage.squashfsCompression = "gzip -Xcompression-level 1";
}
