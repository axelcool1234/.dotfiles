#--- Environment Variables ---#
$env.EDITOR = "hx"
$env.VOLUME_STEP = 5
$env.BRIGHTNESS_STEP = 5

#--- Aliases ---#
alias cl = clear
alias lgit = lazygit
alias grep = grep --color=auto
alias ll = ls -l

#--- Settings ---#
$env.config.buffer_editor = "hx"

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
zoxide init nushell | save -f ($nu.default-config-dir | path join "zoxide.nu")
source ($nu.default-config-dir | path join "zoxide.nu")

# Catpuccin Theme
source ($nu.default-config-dir | path join "catppuccin_macchiato.nu")
# source ($nu.default-config-dir | path join "catppuccin_mocha.nu")
