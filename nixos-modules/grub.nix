{ lib, config, theme, ... }:
let
  grubThemePackage = theme.lookupAssetSource "grub";
in
{
  options = {
    grub.enable =
      lib.mkEnableOption "enables grub";
  };
  config = lib.mkIf config.grub.enable {
    boot.loader.efi.efiSysMountPoint = "/boot";
    boot.loader.efi.canTouchEfiVariables = true;

    boot.loader.grub = {
      enable = true;
      efiSupport = true;
      useOSProber = true;
      configurationLimit = 10;
      device = "nodev"; # efi only
    } // lib.optionalAttrs (grubThemePackage != null) {
      theme = grubThemePackage;
    };
  };
}
