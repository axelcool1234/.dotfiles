# Aliases
alias cl="clear"
alias lgit="lazygit"
alias grep 'grep --color=auto'
alias ll 'ls -l'
alias ls 'ls --color=auto'
alias home-switch 'home-manager switch --flake $HOME/.dotfiles#axelcool1234'
alias nixos-switch 'sudo nixos-rebuild switch --flake $HOME/.dotfiles#default'
alias nsgc="sudo nix-store --gc"
alias ngc="sudo nix-collect-garbage -d"
alias ngc7="sudo nix-collect-garbage --delete-older-than 7d"
alias ngc14="sudo nix-collect-garbage --delete-older-than 14d"
alias goto="cd (dirname (fzf))"
alias govi="vim (fzf)"

set -gx EDITOR hx
set -gx VOLUME_STEP 5
set -gx BRIGHTNESS_STEP 5

set -Ux FZF_DEFAULT_OPTS "\
--color=bg+:#363a4f,bg:#24273a,spinner:#f4dbd6,hl:#ed8796 \
--color=fg:#cad3f5,header:#ed8796,info:#c6a0f6,pointer:#f4dbd6 \
--color=marker:#f4dbd6,fg+:#cad3f5,prompt:#c6a0f6,hl+:#ed8796"

starship init fish | source
zoxide init fish | source
