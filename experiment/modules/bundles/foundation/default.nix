{ self, ... }:
{
  imports = [
    self.features.loacale
    self.features.networking
    self.features.nix
    self.features.users
  ];
}
