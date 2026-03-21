{ lib }:
let
  # Hex character lookup used for rgba conversion helpers.
  hexDigits = {
    "0" = 0;
    "1" = 1;
    "2" = 2;
    "3" = 3;
    "4" = 4;
    "5" = 5;
    "6" = 6;
    "7" = 7;
    "8" = 8;
    "9" = 9;
    "a" = 10;
    "A" = 10;
    "b" = 11;
    "B" = 11;
    "c" = 12;
    "C" = 12;
    "d" = 13;
    "D" = 13;
    "e" = 14;
    "E" = 14;
    "f" = 15;
    "F" = 15;
  };

  # Convert a two-character hex byte into its integer value.
  pairToInt = pair:
    (hexDigits.${builtins.substring 0 1 pair} * 16) + hexDigits.${builtins.substring 1 1 pair};

  # Read the shared palette from a theme bundle.
  getPalette = themeBundle:
    if themeBundle != null && themeBundle ? data && themeBundle.data ? palette then
      themeBundle.data.palette
    else
      throw "theme.data.palette is required";

  # Normalize palette entries to bare rrggbb hex for internal conversions.
  normalizeHex = color:
    if lib.hasPrefix "#" color then lib.removePrefix "#" color else color;

  # Read one palette color as a CSS hex string.
  getHex = themeBundle: name: "#${normalizeHex (getPalette themeBundle).${name}}";

  # Read one palette color as a CSS rgba() string.
  getRgba = themeBundle: name: alpha:
    let
      color = normalizeHex (getPalette themeBundle).${name};
      red = pairToInt (builtins.substring 0 2 color);
      green = pairToInt (builtins.substring 2 2 color);
      blue = pairToInt (builtins.substring 4 2 color);
    in
    "rgba(${toString red}, ${toString green}, ${toString blue}, ${toString alpha})";

  # Build the canonical theme bundle record.
  mkThemeBundle = {
    meta ? { },
    source ? null,
    apps ? { },
    data ? { },
  }:
    {
      inherit meta source apps data;
    };

  # Declare a family-backed theme source such as Catppuccin Mocha.
  mkFamilySource = {
    family,
    variant,
    accent ? null,
    mode ? null,
    extra ? { },
  }:
    {
      type = "family";
      inherit family variant accent mode;
    }
    // extra;

  # Declare a Stylix-backed theme source.
  mkStylixSource = extra:
    {
      type = "stylix";
    }
    // extra;

  # Describe an app themed directly by Stylix.
  mkStylixProvider = {
    target ? null,
    notes ? [ ],
    options ? { },
  }:
    {
      type = "stylix";
      inherit target notes options;
    };

  # Describe an app themed through module options.
  mkModuleProvider = {
    module,
    package ? null,
    attrPath ? [ ],
    options ? { },
    notes ? [ ],
  }:
    {
      type = "module";
      inherit module package attrPath options notes;
    };

  # Describe an app themed by selecting a package or plugin.
  mkPackageProvider = {
    packageSet,
    attrPath,
    package ? null,
    options ? { },
    notes ? [ ],
  }:
    {
      type = "package";
      inherit packageSet attrPath package options notes;
    };

  # Describe an app themed by copying a single upstream asset.
  mkAssetProvider = {
    package ? null,
    source,
    target,
    options ? { },
    notes ? [ ],
  }:
    {
      type = "asset";
      inherit package source target options notes;
    };

  # Describe an app themed by copying an asset plus a local wrapper config.
  mkAssetImportProvider = {
    package ? null,
    source,
    target,
    wrapperFile,
    wrapperTarget,
    options ? { },
    notes ? [ ],
  }:
    {
      type = "asset+import";
      inherit package source target wrapperFile wrapperTarget options notes;
    };

  # Describe an app themed by rendering a small local text template.
  mkTemplateProvider = {
    target ? null,
    options ? { },
    notes ? [ ],
  }:
    {
      type = "template";
      inherit target options notes;
    };

  # Describe an app themed by a fully custom local file.
  mkCustomProvider = {
    file,
    target ? null,
    options ? { },
    notes ? [ ],
  }:
    {
      type = "custom";
      inherit file target options notes;
    };

  # Build one app entry inside a theme bundle.
  mkApp = {
    provider,
    enable ? true,
    notes ? [ ],
  }:
    {
      inherit enable provider notes;
    };

  # Check whether an app entry exists in a theme bundle.
  hasApp = themeBundle: app:
    themeBundle != null
    && themeBundle ? apps
    && builtins.hasAttr app themeBundle.apps;

  # Check whether an app entry both exists and is enabled.
  isAppEnabled = themeBundle: app:
    hasApp themeBundle app && themeBundle.apps.${app}.enable;

  # Read an app provider, returning null when the app is disabled.
  getAppProvider = themeBundle: app:
    if isAppEnabled themeBundle app then themeBundle.apps.${app}.provider else null;

  # Materialize a pinned GitHub repo used by asset-based providers.
  fetchGithubPackage = package:
    if package == null || package.type != "github" || package.rev == null then
      null
    else
      fetchGit {
        url = "https://github.com/${package.repo}.git";
        rev = package.rev;
      };

  # Resolve the concrete path to an upstream asset or asset directory.
  resolveAssetSource = provider:
    if provider == null then
      null
    else if !(builtins.elem provider.type [ "asset" "asset+import" ]) then
      null
    else
      let
        repo = fetchGithubPackage (provider.package or null);
      in
      if repo == null then null else repo + "/${provider.source}";

  # Read the text of a wrapper file used by asset+import providers.
  resolveWrapperText = provider:
    if provider == null || !(provider ? wrapperFile) || provider.wrapperFile == null then
      null
    else
      builtins.readFile provider.wrapperFile;

  # Merge multiple bundles, preferring later values recursively.
  mergeBundles = bundles:
    lib.foldl'
      (
        acc: bundle:
        {
          meta = lib.recursiveUpdate acc.meta (bundle.meta or { });
          source = if bundle ? source && bundle.source != null then bundle.source else acc.source;
          apps = lib.recursiveUpdate acc.apps (bundle.apps or { });
          data = lib.recursiveUpdate acc.data (bundle.data or { });
        }
      )
      {
        meta = { };
        source = null;
        apps = { };
        data = { };
      }
      bundles;

  # Lightweight descriptor for a GitHub-backed upstream source.
  githubPackage = {
    repo,
    rev ? null,
  }:
    {
      type = "github";
      inherit repo rev;
    };
in
{
  inherit
    githubPackage
    getAppProvider
    hasApp
    isAppEnabled
    mergeBundles
    fetchGithubPackage
    getHex
    mkApp
    mkAssetImportProvider
    mkAssetProvider
    mkCustomProvider
    mkFamilySource
    mkModuleProvider
    mkPackageProvider
    mkStylixProvider
    mkStylixSource
    mkTemplateProvider
    mkThemeBundle
    pairToInt
    getPalette
    getRgba
    resolveAssetSource
    resolveWrapperText
    ;
}
