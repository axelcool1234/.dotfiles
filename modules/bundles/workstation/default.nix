{ self, ... }:
{
  imports = [
    self.features.desktop                # Desktop/session base
    self.features.desktop-extras         # Desktop applications
    self.features.environment            # Shell
    self.features.sound                  # Audio
    self.features.printing               # Printing
    self.features.dirs                   # Standard directories
    self.features.fonts                  # Centralized font defaults + fontconfig
    self.features.theming                # Theming
    self.features.grub                   # Bootloader
    self.features.bluetooth              # Bluetooth
    self.features.power                  # Power management
  ];
}
