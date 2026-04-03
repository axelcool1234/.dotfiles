{ self, inputs, lib, myLib, ... }:
let
  # `specialArgs` are extra arguments injected into every module in every host.
  # This lets modules accept `self`, `inputs`, `lib`, `myLib`, and `baseVars`
  # directly instead of computing them again.
  specialArgs = {
    inherit self inputs lib myLib;
    baseVars = {
      username = "axelcool1234";
    };
  };

  mkHostConfiguration =
    {
      hostName,
      modules,
      system,
      stateVersion ? "26.05",
    }:
    let
      hostVars = {
        inherit hostName stateVersion;
      };

      # Host builds get a package set that knows which machine is being
      # evaluated so wrappers can branch on `hostVars.hostName` when needed.
      selfPkgs = myLib.mkPackageSet {
        pkgs = import inputs.nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
        inherit system hostVars;
      };
    in
    lib.nixosSystem {
      inherit system modules;
      specialArgs = specialArgs // {
        inherit hostVars selfPkgs;
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
  legion = mkHostConfiguration {
    hostName = "legion";
    system = "x86_64-linux";
    modules = [
      self.bundles.foundation
      self.bundles.workstation
      self.features.games
      self.hosts.legion
    ];
  };

  # Concrete machine definition for the Fermi system.
  fermi = mkHostConfiguration {
    hostName = "fermi";
    system = "x86_64-linux";
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
  vm = mkHostConfiguration {
    hostName = "vm";
    system = "x86_64-linux";
    modules = [
      self.bundles.foundation
      self.bundles.workstation
      self.hosts.vm
    ];
  };

  # Installer ISO target for bootstrapping fresh installs from this flake.
  #
  # Build with:
  # `nix build .#nixosConfigurations.iso.config.system.build.isoImage`
  iso = mkHostConfiguration {
    hostName = "installer";
    system = "x86_64-linux";
    modules = [
      self.bundles.foundation
      self.features.environment
      self.features.desktop
      self.features.sound
      self.hosts.iso
    ];
  };
}
