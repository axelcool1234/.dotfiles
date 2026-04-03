{
  hostVars ? { },
  lib,
  wlib,
  ...
}:
let
  useNoctaliaTheme = (hostVars.desktop-shell or null) == "noctalia-shell";
in
{
  imports = [ wlib.wrapperModules.btop ];

  config = {
    escapingFunction = wlib.escapeShellArgWithEnv;

    flags."--themes-dir" = lib.mkIf useNoctaliaTheme ''${"$"}HOME/.config/btop/themes'';

    settings = lib.mkMerge [
      {
        vim_keys = true;
      }
      (lib.mkIf useNoctaliaTheme {
        color_theme = "noctalia";
      })
    ];
  };
}
