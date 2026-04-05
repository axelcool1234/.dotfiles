{ hostVars, ... }:
{
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];

    # Deduplicate identical files in the store as paths are added.
    auto-optimise-store = true;

    # `llm-agents.nix` publishes binaries to Numtide's cache.
    extra-substituters = [ "https://cache.numtide.com" ];
    extra-trusted-public-keys = [
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
    ];
  };

  nix.gc = {
    options = "--delete-older-than 30d";
    automatic = true;
    persistent = true;
  };

  nix.optimise = {
    automatic = true;
    persistent = true;
  };

  # https://nixos-and-flakes.thiscute.world/best-practices/nix-path-and-flake-registry
  nix.channel.enable = false; # remove nix-channel related tools & configs, we use flakes instead.  

  nixpkgs.config.allowUnfree = true;
  system.stateVersion = hostVars.stateVersion;
}
