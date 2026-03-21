{ lib, config, themes, theme, ... }:
with lib;
let
  program = "nushell";
  program-module = config.modules.${program};
  neovimProvider = themes.helpers.getAppProvider theme "neovim";
  configNu = ''
    #--- Environment Variables ---#
    $env.EDITOR = "hx"
    $env.VOLUME_STEP = 5
    $env.BRIGHTNESS_STEP = 5

    $env.DOTFILES_THEME_FAMILY = ${builtins.toJSON theme.source.family}
    $env.DOTFILES_THEME_FLAVOR = ${builtins.toJSON theme.source.variant}
    $env.DOTFILES_THEME_ACCENT = ${builtins.toJSON theme.source.accent}
    $env.NVIM_COLORSCHEME = ${builtins.toJSON neovimProvider.options.colorscheme}

    #--- Aliases ---#
    alias cl = clear
    alias lgit = lazygit
    alias grep = grep --color=auto
    alias ll = ls -l
    alias fg = job unfreeze

    #--- Settings ---#
    $env.config.buffer_editor = "hx"
    $env.config.history.file_format = "sqlite"

    #--- Hooks ---#
    # NixOS command_not_found Hook
    $env.config.hooks.command_not_found = {
      |command_name|
      print (command-not-found $command_name | str trim)
    }
    # $env.config.hooks.command_not_found = source "command-not-found.nu"

    #--- Miscellaneous Setups ---#

    # Starship Setup
    mkdir ($nu.data-dir | path join "vendor/autoload")
    starship init nu | save -f ($nu.data-dir | path join "vendor/autoload/starship.nu")

    # Zoxide Setup
    # zoxide init nushell | save -f ($nu.default-config-dir | path join "zoxide.nu")
    # source ($nu.default-config-dir | path join "zoxide.nu")
    const ZOXIDE_PATH = ($nu.default-config-dir | path join "zoxide.nu")
    if not ($ZOXIDE_PATH | path exists) {
        zoxide init nushell | save -f $ZOXIDE_PATH
    }
    const NOZOXIDE = "/dev/null"
    const zoxide_file = (if ($ZOXIDE_PATH | path exists) { $ZOXIDE_PATH } else { $NOZOXIDE })
    source $zoxide_file

    # Yazi shell wrapper
    def --env y [...args] {
    	let tmp = (mktemp -t "yazi-cwd.XXXXXX")
    	yazi ...$args --cwd-file $tmp
    	let cwd = (open $tmp)
    	if $cwd != "" and $cwd != $env.PWD {
    		cd $cwd
    	}
    	rm -fp $tmp
    }

    # Catpuccin Theme
    const THEME_NU = "~/.config/dotfiles-theme/nushell.nu"
    source $THEME_NU

    const FZF_THEME_NU = "~/.config/dotfiles-theme/fzf.nu"
    source $FZF_THEME_NU

    #--- Custom Commands ---#
    use hhx.nu

    #--- Keybinds ---#
    $env.config.keybindings ++= [
      {
        name: "unfreeze",
        modifier: control,
        keycode: "char_z",
        event: {
          send: executehostcommand,
          cmd: "job unfreeze"
        },
        mode: emacs
      }
    ]
  '';
in
{
  options.modules.${program} = {
    enable = mkEnableOption "enables ${program} config";
  };
  config = mkIf program-module.enable {
    programs.${program}.enable = true;
    xdg.configFile = {
      "${program}/config.nu".text = configNu;
      "${program}/hhx.nu".source = ./hhx.nu;
      "${program}/command-not-found.nu".source = ./command-not-found.nu;
    };
  };
}
