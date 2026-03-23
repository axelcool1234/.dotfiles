{ pkgs, lib, config, theme, ... }:
with lib;
let
  program = "yazi";
  program-module = config.modules.${program};
  yaziSyntectProvider = theme.lookupProvider "yaziSyntectTheme";
  yaziSyntectSource = theme.lookupAssetSource yaziSyntectProvider;
  defaultYaziSyntectTarget =
    if theme.source ? variant && theme.source ? accent then
      "yazi/catppuccin-${theme.source.variant}-${theme.source.accent}.tmTheme"
    else
      "yazi/theme.tmTheme";

  # Prefer the syntect provider's declared target when present, otherwise fall
  # back a generic default path.
  yaziSyntectTarget =
    theme.matchProvider yaziSyntectProvider {
      null = defaultYaziSyntectTarget;
      asset = provider: if provider.target != null then provider.target else defaultYaziSyntectTarget;
      default = _: defaultYaziSyntectTarget;
    };
  yaziSyntectFileName = baseNameOf yaziSyntectTarget;

  # Yazi itself only consumes asset-backed themes; when a syntect theme exists,
  # rewrite the upstream theme.toml so previews point at the realized tmTheme.
  yaziThemeSource = theme.matchProvider program {
    null = null;
    asset = _:
      if yaziSyntectSource != null then
        pkgs.runCommandLocal "dotfiles-yazi-theme.toml" { } ''
          sed -E 's|^[[:space:]]*#?[[:space:]]*syntect_theme[[:space:]]*=[[:space:]]*.*$|syntect_theme = "./${yaziSyntectFileName}"|' \
            ${theme.requireAssetSource program} > "$out"
        ''
      else
        theme.requireAssetSource program;
    default = _: null;
  };
  yaziSyntectAliasTargets =
    let
      aliases = theme.lookupProviderOption yaziSyntectProvider "aliases";
    in
    if builtins.isList aliases then aliases else [ ];
in
{
  options.modules.${program} = {
    enable = mkEnableOption "enables ${program} config";
  };
  config = mkIf program-module.enable {
    programs.${program} = {
      enable = true;
      enableNushellIntegration = true;
      shellWrapperName = "yy"; # TODO: This should be removed eventually when I update `home.stateVersion` in `flake.nix`
    };
    xdg.configFile =
      lib.optionalAttrs (yaziThemeSource != null) {
        "yazi/theme.toml".source = yaziThemeSource;
      }
      // lib.optionalAttrs (yaziSyntectSource != null) {
        "${yaziSyntectTarget}".source = yaziSyntectSource;
      }
      // lib.foldl' (acc: aliasTarget: acc // {
        "${aliasTarget}".source = yaziSyntectSource;
      }) { } (if yaziSyntectSource != null then yaziSyntectAliasTargets else [ ]);
  };
}
