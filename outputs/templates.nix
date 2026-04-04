{ lib, myLib, ... }:
let
  templatesDir = ../templates;
  templateDirs = myLib.importTree.dirsWithFile templatesDir "flake.nix";
  templateNames = lib.attrNames templateDirs;

  templates = builtins.listToAttrs (
    map (name: {
      inherit name;
      value = {
        # Template paths should point at the directory to copy. Keeping one
        # `flake.nix` per folder still makes this effectively a single-file
        # template today while leaving room for extra files later.
        path = templatesDir + "/${name}";
        description = "${name} template";
      };
    }) templateNames
  );

  defaultName =
    if builtins.elem "rust" templateNames then
      "rust"
    else
      builtins.head templateNames;
in
templates
// {
  default = templates.${defaultName};
}
