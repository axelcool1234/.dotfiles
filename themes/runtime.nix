{ lib, internal }:
let
  # Materialize a pinned GitHub repo used by asset-based providers.
  # Inputs:
  # - package: attrset|null, GitHub-backed package descriptor
  # Output:
  # - path|null, fetched repo root in the store
  fetchGithubPackage = package:
    if package == null || package.type != "github" || package.rev == null then
      null
    else
      fetchGit {
        url = "https://github.com/${package.repo}.git";
        rev = package.rev;
      };

  # Resolve the concrete path to an upstream asset or asset directory.
  # Inputs:
  # - provider: attrset|null, provider record
  # Output:
  # - path|null, resolved asset path in the store
  # - returns null for non-asset providers or unresolved sources
  resolveAssetSource = provider:
    if provider == null then
      null
    else if provider.type != "asset" then
      null
    else
      let
        repo = fetchGithubPackage (provider.package or null);
      in
      if repo == null then null else repo + "/${provider.source}";

  # Enrich one plain theme bundle with runtime helpers used by consumer modules.
  # Inputs:
  # - theme: attrset, plain theme bundle from one family or Stylix
  # Output:
  # - attrset, runtime theme bundle with accessor/resolver conveniences and mode flags
  withRuntime = theme:
    let
      accessors = import ./accessors.nix {
        inherit internal resolveAssetSource theme;
      };

      resolveInput = input:
        if builtins.isString input then
          accessors.lookupProvider input
        else
          input;

      sourceType =
        if theme != null && theme ? source && theme.source ? type then
          theme.source.type
        else
          null;
    in
    theme
    // accessors # Provide accessors to the theme bundle
    // {
      sourceType = sourceType;
      isFamily = sourceType == "family";
      isStylix = sourceType == "stylix";

      # Check whether one app/provider should be treated as Stylix-owned for this runtime theme.
      # Inputs:
      # - input: string|attrset|null, either app key, provider, or null provider value
      # Output:
      # - bool
      isHandledByStylix = input:
        let
          provider = resolveInput input;
        in
        sourceType == "stylix"
        && provider == null;

      # Run one callback only when an app/provider is not handled by Stylix.
      # Inputs:
      # - input: string|attrset|null, either app key, provider, or null provider value
      # - f: function, called with the resolved provider when it is not Stylix-owned
      # Output:
      # - arbitrary value|null, `null` when Stylix handles the app
      ifNotHandledByStylix = input: f:
        let
          provider = resolveInput input;
        in
        if sourceType == "stylix" && provider == null then
          null
        else
          f provider;

      # Resolve one app/provider input to an upstream asset source.
      # Inputs:
      # - input: string|attrset|null, either app key or provider or none
      # Output:
      # - path|null, resolved asset path in the store
      lookupAssetSource = input: resolveAssetSource (resolveInput input);

      # Check whether one app/provider input resolves to an asset provider.
      # Inputs:
      # - input: string|attrset|null, either app key, provider, or null provider value
      # Output:
      # - bool
      providerIsAsset = input:
        let
          provider = resolveInput input;
        in
        provider != null && provider.type == "asset";

      # Check whether one app/provider input resolves to a structured provider.
      # Inputs:
      # - input: string|attrset|null, either app key, provider, or null provider value
      # Output:
      # - bool
      providerIsStructured = input:
        let
          provider = resolveInput input;
        in
        provider != null && provider.type == "structured";

      # Match one app/provider input against provider shape.
      # Inputs:
      # - input: string|attrset|null, either app key, provider, or null provider value
      # - handlers: attrset, optional handlers for `null`, `asset`, `structured`,
      #   or `default`
      # Output:
      # - arbitrary value returned by the selected handler
      # - throws if no matching handler exists
      matchProvider = input: handlers:
        let
          provider = resolveInput input;
        in
        if provider == null then
          if builtins.hasAttr "null" handlers then handlers.null else null
        else if builtins.hasAttr provider.type handlers then
          (builtins.getAttr provider.type handlers) provider
        else if builtins.hasAttr "default" handlers then
          handlers.default provider
        else
          throw "theme.matchProvider has no handler for provider type ${provider.type}";
    };
in
{
  inherit withRuntime;
}
