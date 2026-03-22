{ lib }:
let
  # Provider resolution helpers.
  # These functions turn provider descriptors into concrete paths or text. They do not
  # inspect a selected theme bundle and can be used independently of runtime accessors.

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
    else if !(builtins.elem provider.type [ "asset" "asset+import" ]) then
      null
    else
      let
        repo = fetchGithubPackage (provider.package or null);
      in
      if repo == null then null else repo + "/${provider.source}";

  # Read the text of a wrapper file used by asset+import providers.
  # Inputs:
  # - provider: attrset|null, provider record
  # Output:
  # - string|null, wrapper file contents
  resolveWrapperText = provider:
    if provider == null || !(provider ? wrapperFile) || provider.wrapperFile == null then
      null
    else
      builtins.readFile provider.wrapperFile;
in
{
  inherit
    resolveAssetSource
    resolveWrapperText
    ;
}
