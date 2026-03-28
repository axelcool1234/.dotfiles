{ self, ... }:
{
  imports = [
    self.features.desktop     # Desktop
    self.features.environment # Shell
    self.features.sound       # Audio
    self.features.theming     # Theming
    self.features.grub        # Bootloader
    self.features.bluetooth   # Bluetooth
  ];
}
