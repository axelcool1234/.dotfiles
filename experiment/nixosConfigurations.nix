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

  # Make sure to run virtual machine with GDK_BACKEND=x11
  # `nix build .#nixosConfigurations.vm.config.system.build.vm`
  # GDK_BACKEND=x11 ./result/bin/run-vm-vm
  vm = lib.nixosSystem {
    specialArgs = specialArgs // {
      hostVars = {
        hostName = "vm";
        stateVersion = "26.05";
      };
    };
    modules = myLib.recursivelyImport [
      ./base
      ./workstation
      ./hosts/vm
    ];
  };
}
