{
  lib,
  self,
  inputs,
  aliases,
}:
let
  importTree = import ./import-tree.nix { inherit lib; };

  # Systems this flake builds package and dev-shell outputs for.
  supportedSystems = [
    "aarch64-darwin"
    "aarch64-linux"
    "x86_64-darwin"
    "x86_64-linux"
  ];

  # Apply a function across all supported flake systems.
  # Inputs:
  # - inputs: attrset, flake inputs containing nixpkgs
  # - apply: function, called with { system, pkgs }
  # Output:
  # - attrset keyed by system
  # Example:
  # - input: forAllSystems inputs ({ system, pkgs }: pkgs.hello)
  # - output: { x86_64-linux = <drv>; aarch64-linux = <drv>; ... }
  forAllSystems =
    inputs: apply:

    # `lib.genAttrs` builds an attrset from a list of names.
    #
    # Input list:
    # [ "aarch64-darwin" "aarch64-linux" "x86_64-darwin" "x86_64-linux" ]
    #
    # For each system string, the lambda below returns the value that should live
    # under that key in the final attrset.
    lib.genAttrs supportedSystems (
      system:

      # `system` is one item from `supportedSystems`, for example:
      # - "x86_64-linux"
      # - "aarch64-linux"
      #
      # We hand that to the caller's `apply` function together with a nixpkgs
      # package set for that system.
      apply {
        inherit system;

        # Import nixpkgs for just this one system.
        # This gives us a `pkgs` attrset whose packages all target that system.
        pkgs = import inputs.nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
      }
    );

  # Detect whether a package exposes impermanence metadata via
  # `passthru.persist`.
  packageHasPersist = pkg:
    builtins.isAttrs pkg
    && pkg ? passthru
    && pkg.passthru ? persist;

  # Collect one persist key from a list of packages that may or may not expose
  # `passthru.persist`.
  collectPersistFromPackages = key: packages:
    lib.pipe packages [
      (builtins.filter packageHasPersist)
      (map (
        pkg: pkg.passthru.persist
      ))
      (map (
        persist: persist.${key} or [ ]
      ))
      lib.flatten
      lib.unique
    ];

  # Build a package set for a specific evaluation context.
  #
  # Generic flake packages use `hostVars = { }`, while host evaluations pass
  # through their concrete `hostVars` so wrappers can branch on machine
  # identity when needed.
  mkPackageSetImpl = myLib:
    {
      pkgs,
      system,
      hostVars,
    }:
    let
      # Wrapper definitions under `wrappers/`.
      # This collects only top-level wrapper entrypoints:
      # - `name.nix`
      # - `name/default.nix`
      #
      # These are modules evaluated by `wrapper-modules`, and they produce wrapped
      # packages such as `fish`, `kitty`, `niri`, and so on.
      wrapperModules = myLib.importTree.entries ../wrappers;
      
      # Real package implementations under `pkgs/`.
      # This also collects only top-level package entrypoints:
      # - `name.nix`
      # - `name/default.nix`
      #
      # We use this folder for custom packages that need logic beyond the wrapper
      # layer.
      directPackages = myLib.importTree.entries ../pkgs;

      
      # Resolve alias specification from the evaluated aliases attrset.
      #
      # Supported forms:
      # - string: look up a package from `basePackages`, then fall back to `pkgs` if it isn't in `basePackages`.
      # - { input = "wrappers"; target = ...; }: look up a local wrapped package
      # - { input = ...; target = ...; }: look up a package from another flake input
      resolveAlias =
        basePackages: spec:
        if builtins.isString spec then
          if builtins.hasAttr spec basePackages then
            basePackages.${spec}
          else if builtins.hasAttr spec pkgs then
            pkgs.${spec}
          else
            throw "Package alias '${spec}' was not found in basePackages or pkgs"
        else if builtins.isAttrs spec && spec ? input && spec ? target then
          if spec.input == "wrappers" then
            if builtins.hasAttr spec.target basePackages then
              basePackages.${spec.target}
            else
              throw "Wrapper alias target '${spec.target}' was not found in basePackages"
          else
            inputs.${spec.input}.packages.${system}.${spec.target}
        else
          throw "Unsupported package alias spec in aliases";
    in
    lib.fix (
      # Full flake output package set for the current system and host.
      # We pass this into wrappers and package files so they can depend on other
      # wrapped packages.
      selfPkgs:
      let
        # Evaluate every wrapper module into a wrapped derivation.
        #
        # `lib.mapAttrs` iterates over the discovered wrapper files.
        # Input to the lambda:
        # - `_name`: wrapper name, like `fish` or `kitty`
        # - `module`: path to the wrapper file
        #
        # Output from the lambda:
        # - wrapped derivation for that wrapper
        wrappedPackages = lib.mapAttrs (
          _name: module:
          # This uses `lib.pipe` because the wrapper flow is naturally a sequence of
          # transformations:
          # 1. start with the wrapper module path
          # 2. evaluate it
          # 3. extract the `wrap` function
          # 4. call that function with `pkgs`
          lib.pipe module [
            # Step 1: evaluate this one wrapper module.
            #
            # Input:
            # - `module`: path to a wrapper file like `../wrappers/fish.nix`
            #
            # Output:
            # - attrset returned by `evalModules`, which includes `config.wrap`
            (module:
              inputs.wrapper-modules.lib.evalModules {
                modules = [ module ];
                specialArgs = {
                  inherit self inputs system pkgs lib myLib selfPkgs hostVars;
                };
              }
            )

            # Step 2: extract the wrapper constructor function.
            #
            # Input:
            # - `evaluated`: attrset from `evalModules`
            #
            # Output:
            # - function that still needs `{ pkgs = ...; }`
            (evaluated: evaluated.config.wrap)

            # Step 3: call the wrapper constructor with this system's `pkgs`.
            #
            # Input:
            # - `wrap`: wrapper constructor function
            #
            # Output:
            # - final wrapped package derivation
            (wrap: wrap { inherit pkgs; })
          ]
        ) wrapperModules;

        # Import every real package file under `pkgs/`.
        #
        # Input to the lambda:
        # - `_name`: package name, like `environment` or `vm`
        # - `packageFile`: path to the package file
        #
        # Output from the lambda:
        # - derivation returned by that file
        importedPackages = lib.mapAttrs (
          _name: packageFile:
          import packageFile {
            inherit
              self
              inputs
              system
              pkgs
              lib
              myLib
              selfPkgs
              hostVars
              ;
          }
        ) directPackages;

        # All real packages for the current system before generating public aliases.
        basePackages = wrappedPackages // importedPackages;

        # Generate public package aliases from the evaluated aliases attrset.
        # Example:
        # - aliases.browser = "glide-browser"
        # - result.browser = basePackages.glide-browser
        #
        # Or for external specs:
        # - aliases.helix-nightly = { input = "modded-helix"; target = "default"; }
        # - result.helix-nightly = inputs.modded-helix.packages.${system}.default
        #
        # Or for local wrapper specs:
        # - aliases.harness = { input = "wrappers"; target = "code"; }
        # - result.harness = basePackages.code
        generatedAliases = lib.mapAttrs (
          _name: spec:
          resolveAlias basePackages spec
        ) (
          lib.filterAttrs (
            _name: spec:
            spec != null
          ) aliases
        );
      in
      # Final package set for one system:
      # 1. real wrapped packages
      # 2. real direct packages
      # 3. generated public aliases
      basePackages // generatedAliases
    );

  helpers = rec {
  inherit
    importTree
    collectPersistFromPackages
    forAllSystems
    ;

    mkPackageSet = mkPackageSetImpl helpers;
  };
in
helpers
