{ theme, lib, ... }:
let
  templates = import ../../themes { inherit lib theme; };
in
{
  xdg.configFile = {
    "dotfiles-theme/hyprland.conf".text = templates.hyprland;
    "dotfiles-theme/waybar.css".text = templates.waybar;
    "dotfiles-theme/kitty.conf".text = templates.kitty;
    "dotfiles-theme/wezterm.lua".text = templates.wezterm;
    "dotfiles-theme/fish.fish".text = templates.fish;
    "dotfiles-theme/rofi.rasi".text = templates.rofi;
    "helix/themes/${theme.helix.themeName}.toml".text = templates.helix;
    "yazi/theme.toml".text = templates.yazi;
    "yazi/${theme.selection.family}-${theme.selection.flavor}.tmTheme".text = templates.yaziSyntectTheme;

    "dotfiles-theme/zathura".text = templates.zathura;
    "dotfiles-theme/nushell.nu".text = templates.nushell;
    "dotfiles-theme/btop.theme".text = templates.btop;
    "dotfiles-theme/discord.css".text = templates.discord;
    "dotfiles-theme/wallpaper.png".source = theme.wallpaper;

    "dotfiles-theme/wlogout.css".text = templates.wlogout;
  };
}
