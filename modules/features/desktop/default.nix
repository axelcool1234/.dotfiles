{
  hostVars,
  myLib,
  ...
}:
let
  compositors = myLib.importTree.entries ./compositors;
  desktopShells = myLib.importTree.entries ./shells;
in
{
  imports =
    builtins.attrValues compositors
    ++ builtins.attrValues desktopShells;

  assertions = [
    {
      assertion =
        hostVars.compositor != null
        && builtins.hasAttr hostVars.compositor compositors;
      message = "hostVars.compositor must name a module under modules/features/desktop/compositors.";
    }
    {
      assertion =
        hostVars.desktopShell == null
        || builtins.hasAttr hostVars.desktopShell desktopShells;
      message = "hostVars.desktopShell must be null or name a module under modules/features/desktop/shells.";
    }
  ];

  users.users.greeter = {
    isNormalUser = false;
    description = "greetd greeter user";
    extraGroups = [ "video" "audio" ];
    linger = true;
  };
}
