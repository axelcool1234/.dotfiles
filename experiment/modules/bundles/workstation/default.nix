{ self, ... }:
{
  imports = [
    self.features.desktop     # Desktop
    self.features.environment # Shell
    self.features.sound       # Audio
    self.features.grub        # Bootloader
    self.features.bluetooth   # Bluetooth
  ];
}
