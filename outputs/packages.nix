{ self, inputs, lib, myLib, ... }:
let
  # Wrapper definitions under `wrappers/`.
  # This collects only top-level wrapper entrypoints:
  # - `name.nix`
  # - `name/default.nix`
  #
  # These are modules evaluated by `wrapper-modules`, and they produce wrapped
  # packages such as `fish`, `kitty`, `niri`, and so on.
  wrapperModules = myLib.collectImmediateModules ../wrappers;

  # Real package implementations under `pkgs/`.
  # This also collects only top-level package entrypoints:
  # - `name.nix`
  # - `name/default.nix`
  #
  # We use this folder for custom packages that need logic beyond the wrapper
  # layer.
  directPackages = myLib.collectImmediateModules ../pkgs;
in
# Build `self.packages` for every supported system.
#
# The callback below is run once per system, for example:
# - x86_64-linux
# - aarch64-linux
#
# Callback input:
# - `pkgs`: nixpkgs package set for that system
# - `system`: system string for that package set
#
# Callback output:
# - attrset of packages for that one system
# - example shape:
#   {
#     fish = <drv>;
#     kitty = <drv>;
#     environment = <drv>;
#     browser = <drv>;
#     shell = <drv>;
#     window-manager = <drv>;
#   }
myLib.forAllSystems inputs (
  { pkgs, system }:
  let
    # Full flake output package set for the current system.
    # We pass this into wrappers and package files so they can depend on other
    # packages from this same flake output.
    selfPkgs = self.packages.${system};

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

            # Extra arguments available to that wrapper module.
            specialArgs = {
              inherit self inputs system pkgs lib selfPkgs;
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
          selfPkgs
          ;
      }
    ) directPackages;

    # All real packages for the current system before generating public aliases.
    basePackages = wrappedPackages // importedPackages;

    # Resolve alias specification from `self.defaults`.
    #
    # Supported forms:
    # - string: look up a package from `basePackages`, then fall back to `pkgs` if it isn't in `basePackages`.
    # - { input = "wrappers"; target = ...; }: look up a local wrapped package
    # - { input = ...; target = ...; }: look up a package from another flake input
    resolveAlias = spec:
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
        throw "Unsupported package alias spec in self.defaults";

    # Generate public package aliases from `self.defaults`.
    # Example:
    # - self.defaults.browser = "glide-browser"
    # - result.browser = basePackages.glide-browser
    #
    # Or for external specs:
    # - self.defaults.helix-nightly = { input = "modded-helix"; target = "default"; }
    # - result.helix-nightly = inputs.modded-helix.packages.${system}.default
    #
    # Or for local wrapper specs:
    # - self.defaults.harness = { input = "wrappers"; target = "code"; }
    # - result.harness = basePackages.code
    generatedAliases = lib.mapAttrs (
      _name: spec:
      resolveAlias spec
    ) self.defaults;
  in
  # Final package set for one system:
  # 1. real wrapped packages
  # 2. real direct packages
  # 3. generated public aliases
  basePackages
  // generatedAliases
)
