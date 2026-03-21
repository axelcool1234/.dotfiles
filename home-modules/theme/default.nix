{
  pkgs,
  lib,
  themes,
  theme ? null,
  ...
}:
let
  inherit (themes.helpers) getAppProvider isAppEnabled resolveAssetSource;

  # This module is the main theme asset realizer. It takes the selected theme bundle
  # from flake specialArgs and turns upstream assets or small generated fragments into
  # concrete XDG files consumed by the rest of the desktop config.

  requireProvider = app: provider:
    if provider == null then
      throw "theme.apps.${app}.provider is required"
    else
      provider;

  requireAssetSource = app: provider:
    let
      resolved = resolveAssetSource (requireProvider app provider);
    in
    if resolved == null then
      throw "theme.apps.${app}.provider must resolve to an asset source"
    else
      resolved;

  requireThemeData = name:
    if theme != null && theme ? data && builtins.hasAttr name theme.data then
      theme.data.${name}
    else
      throw "theme.data.${name} is required";

  renderCssColorVariables = colors:
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: value: "@define-color ${name} ${value};") colors
    );

  renderRasiColorVariables = colors:
    ''
      * {
      ${lib.concatStringsSep "\n" (
        lib.mapAttrsToList (name: value: "  ${name}: ${value};") colors
      )}
      }
    '';

  renderFzfNu = defaultOpts:
    let
      normalizedOpts = lib.removePrefix "$FZF_DEFAULT_OPTS " defaultOpts;
    in
    ''
      let extra_fzf_opts = ${builtins.toJSON normalizedOpts}
      $env.FZF_DEFAULT_OPTS = ([($env.FZF_DEFAULT_OPTS? | default "") $extra_fzf_opts] | where {|x| $x != "" } | str join " ")
    '';

  mkFileTarget = target: source: {
    "${target}".source = source;
  };

  mkFileText = target: text: {
    "${target}".text = text;
  };

  wlogoutThemeText =
    if isAppEnabled theme "wlogout"
      && wlogoutProvider != null
      && wlogoutProvider.type == "template"
      && wlogoutProvider.options ? text then
      wlogoutProvider.options.text
    else
      null;

  waybarThemeText =
    if isAppEnabled theme "waybar"
      && waybarProvider != null
      && waybarProvider.type == "template"
      && waybarProvider.options ? colors then
      renderCssColorVariables waybarProvider.options.colors
    else
      null;

  rofiThemeText =
    if isAppEnabled theme "rofi"
      && rofiProvider != null
      && rofiProvider.type == "template"
      && rofiProvider.options ? colors then
      renderRasiColorVariables rofiProvider.options.colors
    else
      null;

  fzfThemeText =
    if isAppEnabled theme "fzf"
      && fzfProvider != null
      && fzfProvider.type == "template"
      && fzfProvider.options ? defaultOpts then
      renderFzfNu fzfProvider.options.defaultOpts
    else
      null;

  hyprlandProvider = getAppProvider theme "hyprland";
  waybarProvider = getAppProvider theme "waybar";
  rofiProvider = getAppProvider theme "rofi";
  wlogoutProvider = getAppProvider theme "wlogout";
  kittyProvider = getAppProvider theme "kitty";
  btopProvider = getAppProvider theme "btop";
  zathuraProvider = getAppProvider theme "zathura";
  fishProvider = getAppProvider theme "fish";
  fzfProvider = getAppProvider theme "fzf";
  helixProvider = getAppProvider theme "helix";
  yaziProvider = getAppProvider theme "yazi";
  yaziSyntectProvider = getAppProvider theme "yaziSyntectTheme";
  discordProvider = getAppProvider theme "discord";

  fishThemeScript =
    if isAppEnabled theme "fish" then
      pkgs.runCommandLocal "dotfiles-fish-theme.fish" { } ''
        awk '
          /^#/ { next }
          /^$/ { next }
          {
            key = $1
            $1 = ""
            sub(/^ /, "", $0)
            gsub(/"/, "\\\"", $0)
            printf("set -g %s \"%s\"\n", key, $0)
          }
        ' ${requireAssetSource "fish" fishProvider} > "$out"
      ''
    else
      null;

  hyprlandThemeSource =
    if isAppEnabled theme "hyprland"
      && hyprlandProvider != null
      && hyprlandProvider.type == "asset" then
      requireAssetSource "hyprland" hyprlandProvider
    else
      null;

  hyprlandThemeText =
    if isAppEnabled theme "hyprland"
      && hyprlandProvider != null
      && hyprlandProvider.type == "template" then
      hyprlandProvider.options.text
    else
      null;

  yaziSyntectText =
    if isAppEnabled theme "yaziSyntectTheme"
      && yaziSyntectProvider != null
      && yaziSyntectProvider.type == "asset" then
      requireAssetSource "yaziSyntectTheme" yaziSyntectProvider
    else
      null;

  yaziSyntectTarget =
    if yaziSyntectProvider != null && yaziSyntectProvider.target != null then
      yaziSyntectProvider.target
    else
      "yazi/catppuccin-${theme.source.variant}-${theme.source.accent}.tmTheme";

  yaziSyntectFileName = builtins.baseNameOf yaziSyntectTarget;

  yaziThemeSource =
    if isAppEnabled theme "yazi" && yaziSyntectText != null then
      pkgs.runCommandLocal "dotfiles-yazi-theme.toml" { } ''
        sed -E 's|^[[:space:]]*#?[[:space:]]*syntect_theme[[:space:]]*=[[:space:]]*.*$|syntect_theme = "./${yaziSyntectFileName}"|' \
          ${requireAssetSource "yazi" yaziProvider} > "$out"
      ''
    else if isAppEnabled theme "yazi" then
      requireAssetSource "yazi" yaziProvider
    else
      null;

  yaziSyntectAliasTargets =
    if yaziSyntectProvider != null
      && yaziSyntectProvider.options ? aliases
      && builtins.isList yaziSyntectProvider.options.aliases then
      yaziSyntectProvider.options.aliases
    else
      [ ];
in
{
  config.xdg.configFile =
    {
      "dotfiles-theme/wallpaper.png".source = requireThemeData "wallpaper";
    }
    // lib.optionalAttrs (hyprlandThemeSource != null) (mkFileTarget "dotfiles-theme/hyprland.conf" hyprlandThemeSource)
    // lib.optionalAttrs (hyprlandThemeText != null) (mkFileText "dotfiles-theme/hyprland.conf" hyprlandThemeText)
    // lib.optionalAttrs (waybarThemeText != null) (mkFileText "dotfiles-theme/waybar.css" waybarThemeText)
    // lib.optionalAttrs (waybarThemeText == null && isAppEnabled theme "waybar") (mkFileTarget "dotfiles-theme/waybar.css" (requireAssetSource "waybar" waybarProvider))
    // lib.optionalAttrs (rofiThemeText != null) (mkFileText "dotfiles-theme/rofi.rasi" rofiThemeText)
    // lib.optionalAttrs (rofiThemeText == null && isAppEnabled theme "rofi") (mkFileTarget "dotfiles-theme/rofi.rasi" (requireAssetSource "rofi" rofiProvider))
    // lib.optionalAttrs (wlogoutThemeText != null) (mkFileText "dotfiles-theme/wlogout.css" wlogoutThemeText)
    // lib.optionalAttrs (isAppEnabled theme "kitty") (mkFileTarget "dotfiles-theme/kitty.conf" (requireAssetSource "kitty" kittyProvider))
    // lib.optionalAttrs (isAppEnabled theme "btop") (mkFileTarget "dotfiles-theme/btop.theme" (requireAssetSource "btop" btopProvider))
    // lib.optionalAttrs (isAppEnabled theme "zathura") (mkFileTarget "dotfiles-theme/zathura" (requireAssetSource "zathura" zathuraProvider))
    // lib.optionalAttrs (fishThemeScript != null) (mkFileTarget "dotfiles-theme/fish.fish" fishThemeScript)
    // lib.optionalAttrs (fzfThemeText != null) (mkFileText "dotfiles-theme/fzf.nu" fzfThemeText)
    // lib.optionalAttrs (fzfThemeText == null && isAppEnabled theme "fzf") (mkFileTarget "dotfiles-theme/fzf.nu" (requireAssetSource "fzf" fzfProvider))
    // lib.optionalAttrs (isAppEnabled theme "helix") (mkFileTarget "helix/themes/${helixProvider.options.themeName}.toml" (requireAssetSource "helix" helixProvider))
    // lib.optionalAttrs (yaziThemeSource != null) (mkFileTarget "yazi/theme.toml" yaziThemeSource)
    // lib.optionalAttrs (yaziSyntectText != null) (mkFileTarget yaziSyntectTarget yaziSyntectText)
    // lib.foldl' (acc: aliasTarget: acc // mkFileTarget aliasTarget yaziSyntectText) { } (
      if yaziSyntectText != null then yaziSyntectAliasTargets else [ ]
    )
    // lib.optionalAttrs (isAppEnabled theme "discord") (mkFileTarget "dotfiles-theme/discord.css" (requireAssetSource "discord" discordProvider));
}
