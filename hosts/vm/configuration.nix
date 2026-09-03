{ lib, selfPkgs, ... }:
{
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  environment.systemPackages = [
    # Debugging helper for validating the guest audio path.
    selfPkgs.vm-audio-test
  ];

  # Keep the base configuration evaluable as a standalone NixOS output. The
  # QEMU VM variant replaces this with its generated disk-backed root filesystem.
  fileSystems."/" = {
    device = "none";
    fsType = "tmpfs";
  };

  virtualisation.vmVariant = {
    # Known-good QEMU graphics setup for the dedicated compositor test guest.
    virtualisation.qemu.options = [
      "-display"
      "gtk,gl=on"
      "-device"
      "virtio-vga-gl"
    ];

    virtualisation.diskSize = 16 * 1024;

    environment.sessionVariables = lib.mkVMOverride {
      WLR_NO_HARDWARE_CURSORS = "1";
    };
  };

  # Keep the VM guest generic.
  services.qemuGuest.enable = true;

  # Prefer the generic stack inside the guest unless a compositor/module says otherwise.
  services.xserver.videoDrivers = lib.mkDefault [ "modesetting" ];
}
