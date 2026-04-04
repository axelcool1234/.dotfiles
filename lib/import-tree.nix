{ lib }:
let
  inherit (builtins)
    baseNameOf
    dirOf
    filter
    map
    pathExists
    readDir
    stringLength
    substring
    ;
in
{
  # Collect immediate module entrypoints from a boundary directory.
  # Inputs:
  # - dir: path, directory containing `name.nix` files and/or `name/default.nix` folders
  # Output:
  # - attrset mapping module name to either `dir/name.nix` or `dir/name`
  # Will include:
  # - `./modules/features/desktop/default.nix` as `{ desktop = ./modules/features/desktop; }`
  # - `./modules/features/environment.nix` as `{ environment = ./modules/features/environment.nix; }`
  # - `./wrappers/neovim/default.nix` as `{ neovim = ./wrappers/neovim; }`
  # Will not include:
  # - `./modules/features/desktop/niri.nix` because it is nested below the boundary
  # - `./modules/features/storage/impermanence/options.nix` because it is nested below the boundary
  # - a directory without `default.nix`
  entries =
    dir:
    lib.pipe (readDir dir) [
      (lib.mapAttrsToList (
        name: type:
        if type == "regular" && lib.hasSuffix ".nix" name && name != "default.nix" then
          {
            name = lib.removeSuffix ".nix" name;
            value = dir + "/${name}";
          }
        else if type == "directory" && pathExists (dir + "/${name}/default.nix") then
          {
            inherit name;
            value = dir + "/${name}";
          }
        else
          null
      ))
      (filter (entry: entry != null))
      builtins.listToAttrs
    ];

  # Collect descendant directories that contain a marker file.
  # Inputs:
  # - dir: path, directory to scan recursively
  # - marker: string, file name expected inside each kept descendant directory
  # Output:
  # - attrset mapping relative directory path to the matching directory path
  # Will include:
  # - `./skills/host-audit/SKILL.md` as `{ host-audit = ./skills/host-audit; }`
  # - `./templates/rust/flake.nix` as `{ rust = ./templates/rust; }`
  # - `./hosts/vm/configuration.nix` as `{ vm = ./hosts/vm; }`
  # - `./skills/group/nested/SKILL.md` as `{ "group/nested" = ./skills/group/nested; }`
  # Will not include:
  # - directories that do not contain the marker file
  # - regular files living directly under `dir`
  # - the root `dir` itself when the marker exists directly at the root
  dirsWithFile =
    dir: marker:
    let
      dirString = toString dir;
      dirPrefix = dirString + "/";

      relativeDirectoryPath =
        markerPath:
        let
          directoryString = dirOf (toString markerPath);
        in
        if directoryString == dirString then
          ""
        else
          substring
            (stringLength dirPrefix)
            (stringLength directoryString - stringLength dirPrefix)
            directoryString;
    in
    lib.pipe (lib.filesystem.listFilesRecursive dir) [
      (filter (path: baseNameOf (toString path) == marker))
      (map (
        markerPath:
        let
          relativeDir = relativeDirectoryPath markerPath;
        in
        if relativeDir == "" then
          null
        else
          {
            name = relativeDir;
            value = dir + "/${relativeDir}";
          }
      ))
      (filter (entry: entry != null))
      builtins.listToAttrs
    ];

}
