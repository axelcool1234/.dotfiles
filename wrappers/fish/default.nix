{
  hostVars,
  inputs,
  lib,
  pkgs,
  selfPkgs,
  system,
  ...
}:
let
  enableKittyScrollbackCommandEdit = hostVars.terminal == "kitty" && hostVars.editor == "neovim";
  commandNotFoundWrapper = pkgs.writeShellScript "command-not-found" ''
    source ${inputs.nix-index-database.packages.${system}.nix-index-with-small-db}/etc/profile.d/command-not-found.sh
    command_not_found_handle "$@"
  '';
  kittyScrollbackEditCommand = "${pkgs.vimPlugins.kitty-scrollback-nvim}/scripts/edit_command_line.sh";
in
{
  imports = [ ./module.nix ];

  config = {
    runtimePkgs = [
      pkgs.direnv
      pkgs.fzf
      selfPkgs.jjui
      pkgs.lorri
      pkgs.zoxide
    ];

    shellInit = ''
      ${lib.getExe pkgs.zoxide} init fish | source
      ${lib.getExe pkgs.direnv} hook fish | source
      ${lib.getExe pkgs.fzf} --fish | source

      function y
        set --local tmp (mktemp -t "yazi-cwd.XXXXXX")
        ${lib.getExe selfPkgs.yazi} $argv --cwd-file="$tmp"

        if read --zero cwd < "$tmp"; and test "$cwd" != "$PWD"; and test -d "$cwd"
          builtin cd -- "$cwd"
        end

        command rm -f -- "$tmp"
      end

      ${lib.optionalString enableKittyScrollbackCommandEdit ''
        function kitty_scrollback_edit_command_buffer
          set --local --export VISUAL '${kittyScrollbackEditCommand}'
          edit_command_buffer
          commandline ""
        end
      ''}

      function fish_user_key_bindings
        for mode in default insert visual
          bind -M $mode \cz 'fg >/dev/null 2>&1; commandline -f repaint'
          bind -M $mode \cj 'commandline -r jjui; commandline -f execute'
          ${lib.optionalString enableKittyScrollbackCommandEdit ''bind -M $mode \cg kitty_scrollback_edit_command_buffer''}
        end
      end

      function __fish_command_not_found_handler --on-event fish_command_not_found
        ${commandNotFoundWrapper} $argv
      end
    '';

    passthru.persist = {
      homeFiles = [
        ".local/share/fish/fish_history"
      ];
    };

  };

}
