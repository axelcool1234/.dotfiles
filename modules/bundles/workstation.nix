{ self, ... }:
{
  imports = [
    self.features.desktop             # Desktop/session base
    self.features.desktop-environment # Desktop applications
    self.features.environment         # Shell + Shell applications
    self.features.sound               # Audio
    self.features.printing            # Printing
    self.features.dirs                # Standard directories
    self.features.theming             # Theming
    self.features.fonts               # Fonts
    self.features.grub                # Bootloader
    self.features.bluetooth           # Bluetooth
    self.features.power               # Power management
  ];
}
