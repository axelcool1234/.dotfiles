{
  inputs,
  ...
}:
{
  imports = [
    inputs.hjem.nixosModules.default
    ./noctalia-shell/gtk.nix
    ./noctalia-shell/qt.nix
    ./noctalia-shell/noctalia-shell.nix
  ];
}
