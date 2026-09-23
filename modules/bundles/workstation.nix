{ self, ... }:
{
  imports = [
    self.features.desktop                 # Compositor + desktop shell
    self.features.graphical-applications  # GUI applications
    self.features.environment             # Shell + CLI applications
    self.features.sound                   # Audio
    self.features.printing                # Printing
    self.features.dirs                    # Standard directories
    self.features.theming                 # Theming
    self.features.fonts                   # Fonts
    self.features.grub                    # Bootloader
    self.features.bluetooth               # Bluetooth
    self.features.power                   # Power management
  ];
}
