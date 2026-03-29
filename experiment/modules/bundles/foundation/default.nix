{ self, ... }:
{
  imports = [
    self.features.dirs
    self.features.loacale
    self.features.networking
    self.features.nix
    self.features.users
  ];
}
