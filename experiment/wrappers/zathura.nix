{
  config,
  lib,
  self,
  wlib,
  ...
}:
let
  useNoctaliaTheme = self.defaults.desktop-shell == "noctalia-shell";

  formatLine =
    n: v:
    let
      formatValue = value: if lib.isBool value then (if value then "true" else "false") else toString value;
    in
    ''set ${n}	"${formatValue v}"'';

  formatMapLine = n: v: "map ${n}   ${toString v}";

  renderedRcContent =
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList formatLine config.settings
      ++ lib.mapAttrsToList formatMapLine config.mappings
    )
    + lib.optionalString useNoctaliaTheme "\ninclude noctaliarc\n";
in
{
  imports = [ wlib.wrapperModules.zathura ];

  config = {
    escapingFunction = wlib.escapeShellArgWithEnv;

    env.ZATHURA_CONFIG_DIR = ''${"$"}{XDG_STATE_HOME:-${"$"}HOME/.local/state}/zathura-wrapper/config'';
    flags."--config-dir" = lib.mkForce "$ZATHURA_CONFIG_DIR";

    constructFiles.renderedRc.content = lib.mkForce renderedRcContent;

    runShell = [
      ''mkdir -p "$ZATHURA_CONFIG_DIR"''
      ''cp ${config.constructFiles.renderedRc.path} "$ZATHURA_CONFIG_DIR/zathurarc"''
    ] ++ lib.optionals useNoctaliaTheme [
      ''ln -sfn "${"$"}HOME/.config/zathura/noctaliarc" "$ZATHURA_CONFIG_DIR/noctaliarc"''
    ];
  };
}
