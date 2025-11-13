#--- Environment Variables ---#
$env.EDITOR = "hx"
$env.VOLUME_STEP = 5
$env.BRIGHTNESS_STEP = 5

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
source ($nu.default-config-dir | path join "catppuccin_macchiato.nu")
# source ($nu.default-config-dir | path join "catppuccin_mocha.nu")

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