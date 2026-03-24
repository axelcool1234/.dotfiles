{ themeLib, pkgs }:
themeLib.withRuntime (themeLib.families.tokyonight.mk {
  source = {
    variant = "night";
  };
})
