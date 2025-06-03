{ pkgs, lib, config, ... }: 
let
    aliases = {
      # cd = "z";
      # cat = "bat --color=always";
      ls = "ls --color=auto";
      ll = "ls -l";
      grep = "grep --color=auto";
      nixos-switch = "sudo nixos-rebuild switch --flake $HOME/.dotfiles#default";
      home-switch = "home-manager switch --flake $HOME/.dotfiles#axelcool1234";
    };
in
{
  options = {
    zsh.enable = 
      lib.mkEnableOption "enables zsh config";
    bash.enable =
      lib.mkEnableOption "enables bash config";
  };
  config = {
    # Bash Configuration
    programs.bash = lib.mkIf config.bash.enable {
        enable = true;
        shellAliases = aliases; 
        bashrcExtra = ''
        PS1='\[\033[1;31m\][\[\033[1;33m\]\u\[\033[1;32m\]@\[\033[1;34m\]\h:\[\033[35m\]/\w\[\033[31m\]]\[\033[00m\]'
        eval "$(zoxide init bash)"
        '';
    };
    # Zsh Configuration
    programs.zsh = lib.mkIf config.zsh.enable {
        enable = true;
        shellAliases = aliases; 
        initContent = 
        ''
        autoload -U colors && colors
        PS1="%{$fg[red]%}%n%{$reset_color%}@%{$fg[blue]%}%m %{$fg[yellow]%}%~ %{$reset_color%}%% "
        eval "$(zoxide init zsh)"
        '';
    };
  };
}
