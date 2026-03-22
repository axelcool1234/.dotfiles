{ internal, resolvers, theme }:
let
  # Runtime access helpers bound to one selected theme bundle.
  # These functions are the consumer-side API for reading providers, required options,
  # and shared theme data from the selected `theme`.

  inherit (internal) isAppEnabled;
  inherit (resolvers) resolveAssetSource;

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
  # - input: string|attrset, either app key or provider
  # Output:
  # - attrset { app = string|null; provider = attrset|null; }
  resolveProviderInput = input:
    if builtins.isString input then
      {
        app = input;
        provider = providerFor input;
      }
    else
      {
        app = null;
        provider = input;
      };

  # Build a human-readable label for error messages.
  # Inputs:
  # - input: string|attrset, either app key or provider
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
  providerFor = app: getAppProvider theme app;

  # Check whether one app is enabled on the selected theme.
  # Inputs:
  # - app: string, app key
  # Output:
  # - bool
  appEnabled = app: isAppEnabled theme app;

  # Require that an app/provider input resolves to a provider.
  # Inputs:
  # - input: string|attrset, either app key or provider
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
  # - input: string|attrset, either app key or provider
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
  # - input: string|attrset, either app key or provider
  # - name: string, option key
  # Output:
  # - arbitrary value|null
  providerOption = input: name:
    let
      provider = (resolveProviderInput input).provider;
    in
    if provider != null && provider ? options && builtins.hasAttr name provider.options then
      provider.options.${name}
    else
      null;

  # Require one provider option regardless of provider type.
  # Inputs:
  # - input: string|attrset, either app key or provider
  # - name: string, option key
  # Output:
  # - arbitrary value
  # - throws if the option is missing
  requireProviderOption = input: name:
    let
      value = providerOption input name;
    in
    if value != null then
      value
    else
      throw "${providerLabel input}.options.${name} is required";

  # Read one option from a module-backed provider.
  # Inputs:
  # - input: string|attrset, either app key or provider
  # - name: string, option key
  # Output:
  # - arbitrary value|null
  moduleOption = input: name:
    let
      provider = (resolveProviderInput input).provider;
    in
    if provider != null && provider.type == "module" then
      providerOption provider name
    else
      null;

  # Require one option from a module-backed provider.
  # Inputs:
  # - input: string|attrset, either app key or provider
  # - name: string, option key
  # Output:
  # - arbitrary value
  # - throws if the option is missing
  requireModuleOption = input: name:
    let
      value = moduleOption input name;
    in
    if value != null then
      value
    else
      throw "${providerLabel input}.options.${name} is required";

  # Read one option from a template-backed provider.
  # Inputs:
  # - input: string|attrset, either app key or provider
  # - name: string, option key
  # Output:
  # - arbitrary value|null
  templateOption = input: name:
    let
      provider = (resolveProviderInput input).provider;
    in
    if provider != null && provider.type == "template" then
      providerOption provider name
    else
      null;

  # Read the wrapper file path for a provider.
  # Inputs:
  # - input: string|attrset, either app key or provider
  # Output:
  # - path|null
  # Looks first at provider.wrapperFile, then at provider.options.wrapperFile.
  providerWrapperFile = input:
    let
      provider = (resolveProviderInput input).provider;
    in
    if provider == null then
      null
    else if provider ? wrapperFile && provider.wrapperFile != null then
      provider.wrapperFile
    else if providerOption provider "wrapperFile" != null then
      providerOption provider "wrapperFile"
    else
      null;
in
{
  inherit
    appEnabled
    moduleOption
    providerFor
    providerOption
    providerWrapperFile
    requireAssetSource
    requireModuleOption
    requireProvider
    requireProviderOption
    requireThemeData
    templateOption
    ;
}
