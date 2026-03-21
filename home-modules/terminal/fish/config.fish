# Aliases
alias cl="clear"
alias lgit="lazygit"
alias grep 'grep --color=auto'
alias ll 'ls -l'
alias ls 'ls --color=auto'
# alias home-switch 'home-manager switch --flake $HOME/.dotfiles#axelcool1234'
# alias nixos-switch 'sudo nixos-rebuild switch --flake $HOME/.dotfiles#default'
alias nsgc="sudo nix-store --gc"
alias ngc="sudo nix-collect-garbage -d"
alias ngc7="sudo nix-collect-garbage --delete-older-than 7d"
alias ngc14="sudo nix-collect-garbage --delete-older-than 14d"
alias goto="z (dirname (fzf))"
alias govi="vim (fzf)"

set -gx EDITOR hx
set -gx VOLUME_STEP 5
set -gx BRIGHTNESS_STEP 5

source ~/.config/dotfiles-theme/fish.fish

starship init fish | source
zoxide init fish | source
