{ self, inputs, lib, myLib, ... }:
let
  # `specialArgs` are extra arguments injected into every module in every host.
  # This lets modules accept `self`, `inputs`, `defaults`, and `baseVars`
  # directly instead of computing them again.
  specialArgs = {
    inherit self inputs lib myLib;
    baseVars = {
      username = "axelcool1234";
    };
  };
in
{
  # Concrete machine definition for the Legion laptop.
  #
  # `modules` is the ordered list of modules to merge for this machine:
  # 1. foundation bundle: shared baseline modules
  # 2. workstation bundle: shared desktop/laptop stack
  # 3. host module: machine-specific overrides and hardware config
  legion = lib.nixosSystem {
    specialArgs = specialArgs // {
      # `hostVars` are host-specific arguments shared across this machine's modules.
      hostVars = {
        hostName = "legion";
        stateVersion = "26.05";
      };
    };
    modules = [
      self.bundles.foundation
      self.bundles.workstation
      self.hosts.legion
    ];
  };

  # Concrete machine definition for the Fermi system.
  fermi = lib.nixosSystem {
    specialArgs = specialArgs // {
      hostVars = {
        hostName = "fermi";
        stateVersion = "26.05";
      };
    };
    modules = [
      self.bundles.foundation
      self.bundles.workstation
      self.features.open-ssh
      self.hosts.fermi
    ];
  };

  # Concrete machine definition for the VM test environment.
  #
  # Make sure to run the virtual machine with GDK_BACKEND=x11.
  # `nix build .#nixosConfigurations.vm.config.system.build.vm`
  # GDK_BACKEND=x11 ./result/bin/run-vm-vm
  vm = lib.nixosSystem {
    specialArgs = specialArgs // {
      hostVars = {
        hostName = "vm";
        stateVersion = "26.05";
      };
    };
    modules = [
      self.bundles.foundation
      self.bundles.workstation
      self.hosts.vm
    ];
  };
}
