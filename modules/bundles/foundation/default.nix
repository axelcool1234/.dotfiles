{ self, ... }:
{
  imports = [
    self.features.locale
    self.features.networking
    self.features.storage
    self.features.nix
    self.features.users
  ];
}
