{ self, ... }:
{
  imports = [
    self.features.locale
    self.features.networking
    self.features.impermanence # Adds impermanence options; disabled by default.
    self.features.nix
    self.features.users
  ];
}
