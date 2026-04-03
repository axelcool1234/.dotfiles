{
  hostVars,
  modulesPath,
  selfPkgs,
  ...
}:
{
  imports = [
    # Build an official-style installer ISO as the base image.
    (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix")
    ./disko.nix
  ];

  environment.systemPackages = [
    selfPkgs.${hostVars.terminal}
    selfPkgs.${hostVars.browser}
  ];

  # Fast to build, reasonable for an installer image.
  isoImage.squashfsCompression = "gzip -Xcompression-level 1";
}
