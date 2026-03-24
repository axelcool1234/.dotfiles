{ themeLib, pkgs }:
themeLib.withRuntime (themeLib.families.catppuccin.mk {
  source = {
    variant = "mocha";
    accent = "teal";
  };
})
