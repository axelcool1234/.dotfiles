{
  inputs,
  ...
}:
{
  imports = [
    inputs.hjem.nixosModules.default
    ./noctalia/gtk.nix
    ./noctalia/qt.nix
  ];
}
