{
  description = "Flake Config";

  # Flake inputs are the external dependencies this repository can import.
  # Each input becomes available later under `inputs.<name>`.
  inputs = {
    # Main nixpkgs source used for packages and NixOS systems.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Hardware-specific NixOS modules from the NixOS hardware project.
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    # Declarative disk partitioning and formatting.
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Opt-in persistence helpers for ephemeral roots.
    impermanence = {
      url = "github:nix-community/impermanence";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Package wrapping libraries.
    wrappers.url = "github:Lassulus/wrappers";
    wrapper-modules.url = "github:BirdeeHub/nix-wrapper-modules";

    # Browser input for the configured default browser implementation.
    glide = {
      url = "github:glide-browser/glide.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Spotify theming/configuration helper.
    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Package index helpers used by the shell environment.
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Discord/Vesktop configuration module source.
    nixcord.url = "github:FlameFlag/nixcord";

    # Declarative home file manager for files we want linked into the user's home.
    hjem = {
      url = "github:feel-co/hjem";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Custom Helix fork.
    modded-helix = {
      url = "github:axelcool1234/helix/modded";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # External package source for the LLM harness alias.
    llm-agents.url = "github:numtide/llm-agents.nix";

    # Noctalia Shell plugins
    noctalia-plugins = {
      url = "github:noctalia-dev/noctalia-plugins";
      flake = false;
    };
  };

  # `outputs` is the function that turns all flake inputs into the values this
  # flake exports: packages, NixOS configurations, and so on.
  outputs =

    # Pattern-match the argument attrset passed by the flake system.
    #
    # `inputs` is the full attrset of all inputs, including `self`.
    # `self` is also pulled out separately because we use it often.
    # `...` means there may be additional attributes in the input attrset and we
    # do not need to name them all explicitly.
    { self, ... }@inputs:
    let
      # Shared nixpkgs helper library.
      lib = inputs.nixpkgs.lib;

      # Project-local helper functions from `./lib/default.nix`.
      myLib = import ./lib { inherit lib; };

      # Default choices for things like the browser, shell, and window manager.
      defaults = import ./defaults.nix;

      # Common argument attrset passed into every file under `outputs/`.
      # This avoids repeating `inherit self inputs lib myLib;` for each one.
      args = { inherit self inputs lib myLib; };

      # Discover every top-level `.nix` file in `outputs/`.
      # Example shape:
      # {
      #   bundles = ./outputs/bundles.nix;
      #   features = ./outputs/features.nix;
      #   packages = ./outputs/packages.nix;
      #   ...
      # }
      outputFiles = myLib.collectImmediateNixFiles ./outputs;

      # Import each output file with the shared `args` attrset.
      #
      # Input to the lambda:
      # - `_name`: output name, like `packages`
      # - `file`: path to the corresponding file in `outputs/`
      #
      # Output from the lambda:
      # - the value exported by that file, such as the packages attrset or the
      #   nixosConfigurations attrset
      #
      # Output from the whole `mapAttrs` call:
      # {
      #   bundles = <attrset>;
      #   features = <attrset>;
      #   hosts = <attrset>;
      #   ...
      # }
      generatedOutputs = lib.mapAttrs (_name: file: import file args) outputFiles;
    in

    # Final flake outputs.
    #
    # Start with everything generated from `outputs/`, then also expose
    # `defaults` directly as its own top-level flake output.
    generatedOutputs // {
      inherit defaults;
    };
}
