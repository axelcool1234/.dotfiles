{ pkgs, lib, config, theme, ... }: {
  options = {
    grub.enable =
      lib.mkEnableOption "enables grub";
  };
  config = lib.mkIf config.grub.enable {
    assertions = [
      {
        assertion = theme.integrations.grubTheme == null || theme.integrations.grubTheme ? localPackage;
        message = "Theme integration 'grubTheme' must provide a localPackage path or be null.";
      }
    ];

    boot.loader.efi.efiSysMountPoint = "/boot";
    boot.loader.efi.canTouchEfiVariables = true;

    boot.loader.grub = {
      enable = true;
      efiSupport = true;
      useOSProber = true;
      configurationLimit = 10;
      device = "nodev"; # efi only
    } // lib.optionalAttrs (theme.integrations.grubTheme != null) {
      theme = pkgs.callPackage theme.integrations.grubTheme.localPackage { inherit theme; };
    };
  };
}
