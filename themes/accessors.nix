{ internal, resolveAssetSource, theme }:
let
  # Runtime access helpers bound to one selected theme bundle.
  # These functions are the consumer-side API for reading providers, required options,
  # and shared theme data from the selected `theme`.

  inherit (internal) isAppEnabled;

  # Read the enabled provider for an app from a theme bundle.
  # Inputs:
  # - themeBundle: attrset, theme bundle record
  # - app: string, app key
  # Output:
  # - attrset|null, provider record for the enabled app
  getAppProvider = themeBundle: app:
    if isAppEnabled themeBundle app then themeBundle.apps.${app}.provider else null;

  # Normalize one runtime helper input.
  # Inputs:
  # - input: string|attrset|null, either app key, provider, or null provider value
  # Output:
  # - attrset { app = string|null; provider = attrset|null; }
  resolveProviderInput = input:
    if builtins.isString input then
      {
        app = input;
        provider = lookupProvider input;
      }
    else
      {
        app = null;
        provider = input;
      };

  # Build a human-readable label for error messages.
  # Inputs:
  # - input: string|attrset|null, either app key, provider, or null provider value
  # Output:
  # - string, provider label used in thrown error messages
  providerLabel = input:
    let
      resolved = resolveProviderInput input;
    in
    if resolved.app != null then
      "theme.apps.${resolved.app}.provider"
    else
      "theme provider";

  # Read the enabled provider for one app from the selected theme.
  # Inputs:
  # - app: string, app key
  # Output:
  # - attrset|null, provider record
  lookupProvider = app: getAppProvider theme app;

  # Check whether one app is enabled on the selected theme.
  # Inputs:
  # - app: string, app key
  # Output:
  # - bool
  appEnabled = app: isAppEnabled theme app;

  # Require that an app/provider input resolves to a provider.
  # Inputs:
  # - input: string|attrset|null, either app key, provider, or null provider value
  # Output:
  # - attrset provider
  # - throws if the provider is null
  requireProvider = input:
    let
      resolved = resolveProviderInput input;
    in
    if resolved.provider == null then
      throw "${providerLabel input} is required"
    else
      resolved.provider;

  # Require that an app/provider input resolves to an upstream asset source.
  # Inputs:
  # - input: string|attrset|null, either app key, provider, or null provider value
  # Output:
  # - path, resolved asset path
  # - throws if the provider is missing or does not resolve
  requireAssetSource = input:
    let
      resolved = resolveAssetSource (requireProvider input);
    in
    if resolved == null then
      throw "${providerLabel input} must resolve to an asset source"
    else
      resolved;

  # Read one shared data field from the selected theme bundle.
  # Inputs:
  # - name: string, key under theme.data
  # Output:
  # - arbitrary value|null from theme.data
  lookupThemeData = name:
    if theme != null && theme ? data && builtins.hasAttr name theme.data then
      theme.data.${name}
    else
      null;

  # Require one shared data field from the selected theme bundle.
  # Inputs:
  # - name: string, key under theme.data
  # Output:
  # - arbitrary value from theme.data
  # - throws if the key is missing
  requireThemeData = name:
    if theme != null && theme ? data && builtins.hasAttr name theme.data then
      theme.data.${name}
    else
      throw "theme.data.${name} is required";

  # Read one provider option if it exists.
  # Inputs:
  # - input: string|attrset|null, either app key, provider, or null provider value
  # - name: string, option key
  # Output:
  # - arbitrary value|null
  lookupProviderOption = input: name:
    let
      provider = (resolveProviderInput input).provider;
    in
    if provider != null && provider ? options && builtins.hasAttr name provider.options then
      provider.options.${name}
    else
      null;

  # Require one provider option regardless of provider type.
  # Inputs:
  # - input: string|attrset|null, either app key, provider, or null provider value
  # - name: string, option key
  # Output:
  # - arbitrary value
  # - throws if the option is missing
  requireProviderOption = input: name:
    let
      value = lookupProviderOption input name;
    in
    if value != null then
      value
    else
      throw "${providerLabel input}.options.${name} is required";

  # Read one option from a structured-data provider.
  # Inputs:
  # - input: string|attrset|null, either app key, provider, or null provider value
  # - name: string, option key
  # Output:
  # - arbitrary value|null
  lookupStructuredOption = input: name:
    let
      provider = (resolveProviderInput input).provider;
    in
    if provider != null && provider.type == "structured" then
      lookupProviderOption provider name
    else
      null;

  # Require one option from a structured-data provider.
  # Inputs:
  # - input: string|attrset|null, either app key, provider, or null provider value
  # - name: string, option key
  # Output:
  # - arbitrary value
  # - throws if the option is missing
  requireStructuredOption = input: name:
    let
      value = lookupStructuredOption input name;
    in
    if value != null then
      value
    else
      throw "${providerLabel input}.options.${name} is required";

in
{
  inherit
    appEnabled
    lookupProvider
    lookupProviderOption
    lookupStructuredOption
    lookupThemeData
    requireAssetSource
    requireProvider
    requireProviderOption
    requireStructuredOption
    requireThemeData
    ;
}
