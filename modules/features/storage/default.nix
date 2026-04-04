{ myLib, ... }:
{
  imports = builtins.attrValues (myLib.importTree.entries ./impermanence);
}
