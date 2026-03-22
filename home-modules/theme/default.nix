{
  pkgs,
  lib,
  theme ? null,
  ...
}:
let
  realizers = import ./realizers.nix { inherit lib pkgs; };
  inherit (theme)
    appEnabled
    providerFor
    providerOption
    requireAssetSource
    requireThemeData
    templateOption
    ;
  inherit (realizers)
    emitSourceFile
    emitTextFile
    emitTextOrSourceFile
    renderCssColorVariables
    renderFzfNu
    renderFzfShSource
    renderRasiColorVariables
    ;

  # This module is the main theme asset realizer. It takes the selected theme bundle
  # from flake specialArgs and turns upstream assets or small generated fragments into
  # concrete XDG files consumed by the rest of the desktop config.

  emitAppAssetFile = app: provider:
    if appEnabled app then
      emitSourceFile provider.target (requireAssetSource provider)
    else
      { };

  emitTextOrAssetFile = {
    app,
    target,
    text,
    provider,
  }:
    emitTextOrSourceFile target text (
      if text == null && appEnabled app then
        requireAssetSource provider
      else
        null
    );

  providers = lib.genAttrs [
    "hyprland"
    "waybar"
    "rofi"
    "wlogout"
    "kitty"
    "btop"
    "zathura"
    "fish"
    "fzf"
    "helix"
    "yazi"
    "yaziSyntectTheme"
    "discord"
  ] providerFor;

  wlogoutThemeText = templateOption providers.wlogout "text";

  waybarThemeText =
    let
      colors = templateOption providers.waybar "colors";
    in
    if colors != null then renderCssColorVariables colors else null;

  rofiThemeText =
    let
      colors = templateOption providers.rofi "colors";
    in
    if colors != null then renderRasiColorVariables colors else null;

  fzfThemeText =
    let
      defaultOpts = templateOption providers.fzf "defaultOpts";
    in
    if defaultOpts != null then renderFzfNu defaultOpts else null;

  fzfThemeSource =
    if appEnabled "fzf"
      && providers.fzf != null
      && providers.fzf.type == "asset" then
      let
        source = requireAssetSource providers.fzf;
      in
      if lib.hasSuffix ".sh" providers.fzf.source then
        renderFzfShSource source
      else
        source
    else
      null;

  fishThemeScript =
    if appEnabled "fish" then
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
        ' ${requireAssetSource providers.fish} > "$out"
      ''
    else
      null;

  hyprlandThemeSource =
    if appEnabled "hyprland"
      && providers.hyprland != null
      && providers.hyprland.type == "asset" then
      requireAssetSource providers.hyprland
    else
      null;

  hyprlandThemeText = templateOption providers.hyprland "text";

  yaziSyntectText =
    if appEnabled "yaziSyntectTheme"
      && providers.yaziSyntectTheme != null
      && providers.yaziSyntectTheme.type == "asset" then
      requireAssetSource providers.yaziSyntectTheme
    else
      null;

  yaziSyntectTarget =
    if providers.yaziSyntectTheme != null && providers.yaziSyntectTheme.target != null then
      providers.yaziSyntectTheme.target
    else
      "yazi/catppuccin-${theme.source.variant}-${theme.source.accent}.tmTheme";

  yaziSyntectFileName = builtins.baseNameOf yaziSyntectTarget;

  yaziThemeSource =
    if appEnabled "yazi" && yaziSyntectText != null then
      pkgs.runCommandLocal "dotfiles-yazi-theme.toml" { } ''
        sed -E 's|^[[:space:]]*#?[[:space:]]*syntect_theme[[:space:]]*=[[:space:]]*.*$|syntect_theme = "./${yaziSyntectFileName}"|' \
          ${requireAssetSource providers.yazi} > "$out"
      ''
    else if appEnabled "yazi" then
      requireAssetSource providers.yazi
    else
      null;

  yaziSyntectAliasTargets =
    let
      aliases = providerOption providers.yaziSyntectTheme "aliases";
    in
    if builtins.isList aliases then
      aliases
    else
      [ ];
in
{
  config.xdg.configFile =
    {
      "dotfiles-theme/wallpaper.png".source = requireThemeData "wallpaper";
    }
    // emitSourceFile "dotfiles-theme/hyprland.conf" hyprlandThemeSource
    // emitTextFile "dotfiles-theme/hyprland.conf" hyprlandThemeText
    // emitTextOrAssetFile {
      app = "waybar";
      target = "dotfiles-theme/waybar.css";
      text = waybarThemeText;
      provider = providers.waybar;
    }
    // emitTextOrAssetFile {
      app = "rofi";
      target = "dotfiles-theme/rofi.rasi";
      text = rofiThemeText;
      provider = providers.rofi;
    }
    // emitTextFile "dotfiles-theme/wlogout.css" wlogoutThemeText
    // emitAppAssetFile "kitty" providers.kitty
    // emitAppAssetFile "btop" providers.btop
    // emitAppAssetFile "zathura" providers.zathura
    // emitSourceFile "dotfiles-theme/fish.fish" fishThemeScript
    // emitTextFile "dotfiles-theme/fzf.nu" fzfThemeText
    // emitSourceFile "dotfiles-theme/fzf.nu" fzfThemeSource
    // lib.optionalAttrs (providers.helix != null && providers.helix.type == "asset") {
      "helix/themes/${providers.helix.options.themeName}.toml".source = requireAssetSource providers.helix;
    }
    // emitSourceFile "yazi/theme.toml" yaziThemeSource
    // emitSourceFile yaziSyntectTarget yaziSyntectText
    // lib.foldl' (acc: aliasTarget: acc // emitSourceFile aliasTarget yaziSyntectText) { } (
      if yaziSyntectText != null then yaziSyntectAliasTargets else [ ]
    )
    // emitAppAssetFile "discord" providers.discord;
}
