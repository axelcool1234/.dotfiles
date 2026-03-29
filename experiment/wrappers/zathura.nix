{
  config,
  lib,
  pkgs,
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
    plugins = with pkgs.zathuraPkgs; [
      zathura_pdf_mupdf
      zathura_cb
      zathura_djvu
      zathura_ps
    ];

    escapingFunction = wlib.escapeShellArgWithEnv;

    flags."--config-dir" = lib.mkForce "$ZATHURA_CONFIG_DIR";

    constructFiles.renderedRc.content = lib.mkForce renderedRcContent;

    runShell = [
      ''
        runtime_base="${"$"}{XDG_RUNTIME_DIR:-${"$"}{XDG_CACHE_HOME:-${"$"}HOME/.cache}}"
        export ZATHURA_CONFIG_DIR="$(mktemp -d "$runtime_base/zathura-wrapper.XXXXXX")"
      ''
      ''mkdir -p "$ZATHURA_CONFIG_DIR"''
      ''cp ${config.constructFiles.renderedRc.path} "$ZATHURA_CONFIG_DIR/zathurarc"''
    ] ++ lib.optionals useNoctaliaTheme [
      ''ln -sfn "${"$"}HOME/.config/zathura/noctaliarc" "$ZATHURA_CONFIG_DIR/noctaliarc"''
    ];
  };
}
