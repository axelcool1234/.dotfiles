{ self, ... }:
{
  imports = [
    self.features.locale
    self.features.networking
    self.features.nix
    self.features.users
  ];
}
