{ ... }:
{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix

    # Non-hardware stuff
    ./firewall.nix
    ./open-ssh.nix
  ];
  hardware.enableAllFirmware = true;
}
