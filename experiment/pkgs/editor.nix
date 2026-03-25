{
  self,
  pkgs,
  ...
}:
self.packages.${pkgs.stdenv.hostPlatform.system}.helix
