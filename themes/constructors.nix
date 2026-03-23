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

  # Describe an app themed by providing structured local theme data.
  # Inputs:
  # - target: string|null, optional target file path
  # - package: attrset|null, optional upstream package/source descriptor
  # - attrPath: list of strings, optional package attribute path used by consumers
  # - options: attrset, structured consumer payload
  # - notes: list of strings
  # Output:
  # - attrset provider record with type = "structured"
  mkStructuredProvider = {
    target ? null,
    package ? null,
    attrPath ? [ ],
    options ? { },
    notes ? [ ],
  }:
    {
      type = "structured";
      inherit target package attrPath options notes;
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
