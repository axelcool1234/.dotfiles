{ lib }:
let
  /**
    Recursively expand a mixed list of files and directories into a flat list of
    `*.nix` paths.

    This is useful for module assembly where the consumer wants a plain module
    list, for example when feeding `modules = ...` into `lib.nixosSystem`.

    Example:

    ```
    recursivelyImport [
      ./base
      ./hosts/example
    ]
    ```

    # Type

    ```
    recursivelyImport :: [Path | Any] -> [Path | Any]
    ```
  */
  recursivelyImport =
    list:
    let
      inherit (lib) hasSuffix;
      inherit (builtins)
        concatMap
        filter
        isPath
        readFileType
        ;

      expandIfFolder =
        elem:
        if !isPath elem || readFileType elem != "directory" then
          [ elem ]
        else
          lib.filesystem.listFilesRecursive elem;
    in
    filter
      # Filter out any path that doesn't look like `*.nix`. Don't forget to use
      # toString to prevent copying paths to the store unnecessarily
      (elem: !isPath elem || hasSuffix ".nix" (toString elem))
      # Expand any folder to all the files within it.
      (concatMap expandIfFolder list);

  /**
    Recursively collect Nix files from a directory and name them by filename.

    This is meant for flake output discovery, where one file under `wrappedPrograms/`
    should become one named output like `packages.<system>.<name>`.

    It:

    - walks the directory recursively
    - keeps only `*.nix` files
    - skips any `default.nix`
    - uses each file's basename without the `.nix` suffix as the attr name

    Example:

    ```
    ./wrappedPrograms/
      git.nix
      helix.nix

    => {
      git = ./wrappedPrograms/git.nix;
      helix = ./wrappedPrograms/helix.nix;
    }
    ```

    # Inputs

    `dir`

    : Directory to scan recursively

    # Type

    ```
    collectNamedNixFiles :: Path -> AttrSet String Path
    ```
  */
  collectNamedNixFiles =
    dir:
    let
      files = lib.filesystem.listFilesRecursive dir;

      nixFiles = builtins.filter (
        path:
        let
          name = baseNameOf (toString path);
        in
        lib.hasSuffix ".nix" name && name != "default.nix"
      ) files;

      toName = path: lib.removeSuffix ".nix" (baseNameOf (toString path));
    in
    builtins.listToAttrs (
      map (path: {
        name = toName path;
        value = path;
      }) nixFiles
    );
in
{
  inherit collectNamedNixFiles recursivelyImport;
}
