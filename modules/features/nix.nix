{ hostVars, ... }:
{
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
  };

  # https://nixos-and-flakes.thiscute.world/best-practices/nix-path-and-flake-registry
  nix.channel.enable = false; # remove nix-channel related tools & configs, we use flakes instead.  

  nixpkgs.config.allowUnfree = true;
  system.stateVersion = hostVars.stateVersion;
}
