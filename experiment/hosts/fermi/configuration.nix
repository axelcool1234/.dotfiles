{ inputs, ... }:
{
  imports = [
    # Use the upstream board profile for ASUS ROG Strix X570-E systems.
    inputs.nixos-hardware.nixosModules.asus-rog-strix-x570e

    # Include the results of the hardware scan.
    ./hardware-configuration.nix

    # Non-hardware stuff
    ./firewall.nix
    ./impermanence.nix
  ];
  hardware.enableAllFirmware = true;
}
