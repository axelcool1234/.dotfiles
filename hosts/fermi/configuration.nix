{ inputs, pkgs, ... }:
{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix

    # Use the upstream board profile for ASUS ROG Strix X570-E systems.
    inputs.nixos-hardware.nixosModules.asus-rog-strix-x570e

    # Non-hardware stuff
    ./firewall.nix
    ./impermanence.nix
  ];

  # Work around a VT regression in newer kernels that can panic in csi_J while
  # greetd/tuigreet clears tty1 during login (black screen + hard freeze).
  #
  # Fermi hit this on 6.18.20 with a reproducible stack in do_con_write ->
  # csi_J, so pin this host to the mature LTS line until the fix is fully
  # backported in nixpkgs.
  # https://www.spinics.net/lists/linux-serial/msg69608.html                                             
  # https://bugzilla.kernel.org/show_bug.cgi?id=222168 
  boot.kernelPackages = pkgs.linuxPackages_6_12;

  hardware.enableAllFirmware = true;
}
