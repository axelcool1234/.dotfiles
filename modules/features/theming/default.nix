{
  inputs,
  lib,
  self,
  ...
}:
{
  imports = [
    inputs.hjem.nixosModules.default
    ./noctalia-shell/gtk.nix
    ./noctalia-shell/qt.nix
    ./noctalia-shell/noctalia-shell.nix
  ];

  options.preferences.desktop-shell = lib.mkOption {
    type = lib.types.enum [ "noctalia-shell" ];
    default = self.defaults.desktop-shell;
    description = "Desktop shell implementation to use for the session UI layer.";
  };
}
