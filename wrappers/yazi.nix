{
  config,
  hostVars,
  lib,
  wlib,
  ...
}:
let
  useNoctaliaTheme = hostVars.desktop-shell == "noctalia-shell";
in
{
  imports = [ wlib.wrapperModules.yazi ];

  config = {
    escapingFunction = wlib.escapeShellArgWithEnv;

    # Yazi resolves flavors relative to YAZI_CONFIG_HOME. Point it back at the
    # real user config dir so Noctalia-managed flavors under ~/.config/yazi/
    # remain visible. Only do this in Noctalia mode; otherwise leave the
    # upstream wrapper module's generated config location untouched.
    env.YAZI_CONFIG_HOME = lib.mkIf useNoctaliaTheme (lib.mkForce ''${"$"}HOME/.config/yazi'');

    settings.theme = lib.mkIf useNoctaliaTheme {
      flavor = {
        dark = "noctalia";
        light = "noctalia";
      };
    };
  };
}
