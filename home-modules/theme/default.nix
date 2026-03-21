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

  mkFileTarget = target: source: {
    "${target}".source = source;
  };

  mkFileText = target: text: {
    "${target}".text = text;
  };

  wlogoutThemeText =
    if isAppEnabled theme "wlogout"
      && wlogoutProvider != null
      && wlogoutProvider.options ? colors then
      let
        colors = wlogoutProvider.options.colors;
      in
      ''
        @define-color overlay ${colors.overlay};
        @define-color text ${colors.text};
        @define-color surface0 ${colors.surface0};
        @define-color base ${colors.base};
        @define-color accent ${colors.accent};
      ''
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
  nushellProvider = getAppProvider theme "nushell";
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

  hyprlandTemplateText =
    if isAppEnabled theme "hyprland" then
      requireAssetSource "hyprland" hyprlandProvider
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
        sed -E 's#^([[:space:]]*syntect_theme[[:space:]]*=[[:space:]]*).*$#\1"./${yaziSyntectFileName}"#' \
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
    // lib.optionalAttrs (hyprlandTemplateText != null) (mkFileTarget "dotfiles-theme/hyprland.conf" hyprlandTemplateText)
    // lib.optionalAttrs (isAppEnabled theme "waybar") (mkFileTarget "dotfiles-theme/waybar.css" (requireAssetSource "waybar" waybarProvider))
    // lib.optionalAttrs (isAppEnabled theme "rofi") (mkFileTarget "dotfiles-theme/rofi.rasi" (requireAssetSource "rofi" rofiProvider))
    // lib.optionalAttrs (wlogoutThemeText != null) (mkFileText "dotfiles-theme/wlogout.css" wlogoutThemeText)
    // lib.optionalAttrs (isAppEnabled theme "kitty") (mkFileTarget "dotfiles-theme/kitty.conf" (requireAssetSource "kitty" kittyProvider))
    // lib.optionalAttrs (isAppEnabled theme "btop") (mkFileTarget "dotfiles-theme/btop.theme" (requireAssetSource "btop" btopProvider))
    // lib.optionalAttrs (isAppEnabled theme "zathura") (mkFileTarget "dotfiles-theme/zathura" (requireAssetSource "zathura" zathuraProvider))
    // lib.optionalAttrs (fishThemeScript != null) (mkFileTarget "dotfiles-theme/fish.fish" fishThemeScript)
    // lib.optionalAttrs (isAppEnabled theme "nushell") (mkFileTarget "dotfiles-theme/nushell.nu" (requireAssetSource "nushell" nushellProvider))
    // lib.optionalAttrs (isAppEnabled theme "fzf") (mkFileTarget "dotfiles-theme/fzf.nu" (requireAssetSource "fzf" fzfProvider))
    // lib.optionalAttrs (isAppEnabled theme "helix") (mkFileTarget "helix/themes/${helixProvider.options.themeName}.toml" (requireAssetSource "helix" helixProvider))
    // lib.optionalAttrs (yaziThemeSource != null) (mkFileTarget "yazi/theme.toml" yaziThemeSource)
    // lib.optionalAttrs (yaziSyntectText != null) (mkFileTarget yaziSyntectTarget yaziSyntectText)
    // lib.foldl' (acc: aliasTarget: acc // mkFileTarget aliasTarget yaziSyntectText) { } (
      if yaziSyntectText != null then yaziSyntectAliasTargets else [ ]
    )
    // lib.optionalAttrs (isAppEnabled theme "discord") (mkFileTarget "dotfiles-theme/discord.css" (requireAssetSource "discord" discordProvider));
}
