{
  config,
  pkgs,
  ...
}:
{
  imports = [ ./module.nix ];

  config = {
    constructFiles.openInEditor = {
      relPath = "bin/lazygit-open-in-editor";
      builder = ''mkdir -p "$(dirname "$2")" && cp "$1" "$2" && chmod +x "$2"'';
      # TODO: Figure out if there's a way to refer to selfPkgs.editor without getting
      # stuck in an infinite evluation loop. For now, do hardcoded "hx" instead.
      content = ''
        #!${pkgs.bash}/bin/bash
        set -euo pipefail

        file_path="$1"
        line_number="''${2-}"

        if [[ -n "''${HELIX_LAZYGIT_BUFFER_PATH:-}" ]]; then
          shell_pid="$PPID"
          lazygit_pid="$(ps -o ppid= -p "$shell_pid" | tr -d '[:space:]')"

          target="$file_path"
          if [[ -n "$line_number" ]]; then
            target="$target:$line_number"
          fi

          printf '%s\n' "$target" > "$HELIX_LAZYGIT_BUFFER_PATH"

          if [[ -n "$lazygit_pid" ]]; then
            kill -TERM "$lazygit_pid"
          fi

          exit 0
        fi

        if [[ -n "$line_number" ]]; then
          exec hx "$file_path:$line_number"
        fi

        exec hx "$file_path"
      '';
    };

    settings.os = {
      edit = ''${config.constructFiles.openInEditor.path} "{{filename}}"'';
      editAtLine = ''${config.constructFiles.openInEditor.path} "{{filename}}" "{{line}}"'';
    };
  };
}
