{ self, ... }:
{
  imports = [
    self.features.desktop     # Desktop
    self.features.environment # Shell
    self.features.grub        # Bootloader
    self.features.bluetooth   # Bluetooth
  ];
}
