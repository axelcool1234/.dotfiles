{ inputs, lib, baseVars, ... }:
{
  imports = [ inputs.nixos-wsl.nixosModules.default ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  wsl = {
    enable = true;
    defaultUser = baseVars.username;
  };

  # WSL owns the VM network setup, so keep the guest from trying to run its
  # own NetworkManager stack.
  networking.networkmanager.enable = lib.mkForce false;
}
