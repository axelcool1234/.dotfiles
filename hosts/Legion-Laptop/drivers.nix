{ lib, config, pkgs, ... }:

{
  /* from lenovo legion configurations in nixos-hardware */
  # Cooling management
  # I have this commented out because I'm not sure if I need it. I'll leave it here in case I figure it out at some point.
  # services.thermald.enable = lib.mkDefault true;
  # √(2560² + 1600²) px / 16 in ≃ 189 dpi
  services.xserver.dpi = 189;
  /* from nixos-hardware/common/cpu/intel/cpu-only.nix */
    hardware.cpu.intel.updateMicrocode =
    lib.mkDefault config.hardware.enableRedistributableFirmware;
    /* The above is already enabled in hardware-configuration.nix actually. */
  /* from nixos-hardware/common/gpu/intel/default.nix */
  boot.initrd.kernelModules = [ "i915" ];

  environment.variables = {
    VDPAU_DRIVER = lib.mkIf config.hardware.graphics.enable (lib.mkDefault "va_gl");
  };

  hardware.graphics.extraPackages = with pkgs; [
    (if (lib.versionOlder (lib.versions.majorMinor lib.version) "23.11") then vaapiIntel else intel-vaapi-driver)
    libvdpau-va-gl
    intel-media-driver
    vaapiVdpau /* from nixos-hardware/common/gpu/nvidia/default.nix */
  ];

  /* from nixos-hardware/common/pc/default.nix */
  boot.blacklistedKernelModules = lib.optionals (!config.hardware.enableRedistributableFirmware) [
    "ath3k"
  ];

  /* from nixos-hardware/common/pc/laptop/default.nix */
  services.tlp.enable = lib.mkDefault ((lib.versionOlder (lib.versions.majorMinor lib.version) "21.05")
                                     || !config.services.power-profiles-daemon.enable);

  /* from nixos-hardware/common/pc/ssd/default.nix */
  services.fstrim.enable = lib.mkDefault true;

  /* LAPTOP CONFIGURATION */
  boot.kernelPackages = pkgs.linuxKernel.packages.linux_zen;
  boot.kernelParams = [ 
    "quiet"
    "splash"
    "loglevel=3"
    "rd.udev.log_priority=3"
    "systemd.show_status=auto"
    "fbcon=nodefer"
    "vt.global_cursor_default=0"
    "usbcore.autosuspend=-1"
    "video4linux"
    "acpi_rev_override=5"
    "reboot=acpi" /* I believe this has lowered the chance of hanging on shutdown. */
  ];

   /* Everything below is from NixOS guide */
  # Enable OpenGL
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Enable NVIDIA Driver
  services.xserver.videoDrivers = ["nvidia"];
  hardware.nvidia = {

    # Modesetting is required.
    modesetting.enable = true;

    # Nvidia power management. Experimental, and can cause sleep/suspend to fail.
    # Enable this if you have graphical corruption issues or application crashes after waking
    # up from sleep. This fixes it by saving the entire VRAM memory to /tmp/ instead 
    # of just the bare essentials.
    powerManagement.enable = false;

    # Fine-grained power management. Turns off GPU when not in use.
    # Experimental and only works on modern Nvidia GPUs (Turing or newer).
    powerManagement.finegrained = false;

    # Use the NVidia open source kernel module (not to be confused with the
    # independent third-party "nouveau" open source driver).
    # Support is limited to the Turing and later architectures. Full list of 
    # supported GPUs is at:
    # https://github.com/NVIDIA/open-gpu-kernel-modules#compatible-gpus 
    # Only available from driver 515.43.04+
    # Currently alpha-quality/buggy, so false is currently the recommended setting.
    open = false;

    # Enable the Nvidia settings menu,
  	# accessible via `nvidia-settings`.
    nvidiaSettings = true;

    # Optionally, you may need to select the appropriate driver version for your specific GPU.
    package = config.boot.kernelPackages.nvidiaPackages.stable;

    # Offload Mode
    prime = { /* also from nixos-hardware/common/gpu/nvidia/prime.nix */
        offload = {
            enable = true;
            enableOffloadCmd = true;
        };
        # Make sure to use the correct Bus ID values for your system!
        intelBusId = "PCI:00:02:0";
        nvidiaBusId = "PCI:01:00:0";
    };
  };
}
