{ lib }:
{
  # Constructor layer for theme declarations.
  # These functions build theme bundle records, source records, provider records, and
  # app records. They do not inspect a selected runtime theme or resolve files.

  # Build the canonical theme bundle record.
  # Inputs:
  # - meta: attrset, human-oriented metadata
  # - source: attrset|null, selected theme source description
  # - apps: attrset, per-app delivery records
  # - data: attrset, shared derived data
  # Output:
  # - attrset { meta, source, apps, data }
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
  # Inputs:
  # - family: string, family id
  # - variant: string, family member selection
  # - accent: string|null, optional accent selection
  # - mode: string|null, light/dark or similar mode tag
  # - extra: attrset, additional source fields
  # Output:
  # - attrset source record with type = "family"
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

  # Describe an app themed through module options.
  # Inputs:
  # - module: string, consumer module identifier
  # - package: attrset|null, optional package descriptor
  # - attrPath: list of strings, optional package attribute path
  # - options: attrset, module-facing payload
  # - notes: list of strings
  # Output:
  # - attrset provider record with type = "module"
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
  # Inputs:
  # - packageSet: string, package namespace to resolve from
  # - attrPath: list of strings, package attribute path
  # - package: attrset|null, optional upstream package descriptor
  # - options: attrset, package consumer payload
  # - notes: list of strings
  # Output:
  # - attrset provider record with type = "package"
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
  # Inputs:
  # - package: attrset|null, upstream package/source descriptor
  # - source: string, path inside the upstream source
  # - target: string|null, target path in the realized config tree
  # - options: attrset, additional payload
  # - notes: list of strings
  # Output:
  # - attrset provider record with type = "asset"
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
  # Inputs:
  # - package: attrset|null, upstream package/source descriptor
  # - source: string, path inside the upstream source
  # - target: string|null, target path for the upstream asset
  # - wrapperFile: path, repo-local wrapper file
  # - wrapperTarget: string, target path for the wrapper file
  # - options: attrset, additional payload
  # - notes: list of strings
  # Output:
  # - attrset provider record with type = "asset+import"
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
  # Inputs:
  # - target: string|null, target file path
  # - options: attrset, template rendering payload
  # - notes: list of strings
  # Output:
  # - attrset provider record with type = "template"
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
  # Inputs:
  # - file: path, local custom file
  # - target: string|null, target file path
  # - options: attrset, additional payload
  # - notes: list of strings
  # Output:
  # - attrset provider record with type = "custom"
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
  # Inputs:
  # - provider: attrset, provider record
  # - enable: bool, whether this app is enabled in the bundle
  # - notes: list of strings
  # Output:
  # - attrset app record { enable, provider, notes }
  mkApp = {
    provider,
    enable ? true,
    notes ? [ ],
  }:
    {
      inherit enable provider notes;
    };

  # Lightweight descriptor for a GitHub-backed upstream source.
  # Inputs:
  # - repo: string, GitHub OWNER/REPO
  # - rev: string|null, pinned revision
  # Output:
  # - attrset package descriptor with type = "github"
  githubPackage = {
    repo,
    rev ? null,
  }:
    {
      type = "github";
      inherit repo rev;
    };
}
