{ self, inputs }:
let
  lib = inputs.nixpkgs.lib;
  myLib = import ./lib { inherit lib; };
  specialArgs = {
    inherit self inputs;
    baseVars = {
      username = "axelcool1234";
    };
  };
in
{
  legion = lib.nixosSystem {
    specialArgs = specialArgs // {
      hostVars = {
        hostName = "legion";
        stateVersion = "26.05";
      };
    };
    modules = myLib.recursivelyImport [
      ./base
      ./workstation
      ./hosts/legion
    ];
  };

  fermi = lib.nixosSystem {
    specialArgs = specialArgs // {
      hostVars = {
        hostName = "fermi";
        stateVersion = "26.05";
      };
    };
    modules = myLib.recursivelyImport [
      ./base
      ./workstation
      ./hosts/fermi
    ];
  };
}
