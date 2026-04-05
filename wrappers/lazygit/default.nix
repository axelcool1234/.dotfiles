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
      content = ''
        #!${pkgs.bash}/bin/bash
        set -euo pipefail

        file_path="$1"
        line_number="''${2-}"
        shell_pid="$PPID"
        lazygit_pid="$(ps -o ppid= -p "$shell_pid" | tr -d '[:space:]')"
        target_path_file="''${LAZYGIT_OPEN_PATH_FILE:-}"

        if [[ -n "$target_path_file" ]]; then
          target="$file_path"
          if [[ -n "$line_number" ]]; then
            target="$target:$line_number"
          fi

          printf '%s\n' "$target" > "$target_path_file"

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

    constructFiles.openStandalone = {
      relPath = "bin/lazygit-standalone";
      builder = ''mkdir -p "$(dirname "$2")" && cp "$1" "$2" && chmod +x "$2"'';
      content = ''
        #!${pkgs.bash}/bin/bash
        set -euo pipefail

        script_dir="$(cd "$(dirname "$0")" && pwd)"

        target_path_file="$(mktemp)"
        stderr_log="$(mktemp)"
        trap 'rm -f "$target_path_file" "$stderr_log"' EXIT
        export LAZYGIT_OPEN_PATH_FILE="$target_path_file"

        set +e
        exec 3>&2
        exec 2>"$stderr_log"
        "$script_dir/lazygit" "$@"
        status=$?
        exec 2>&3
        exec 3>&-
        set -e

        if [[ -s "$target_path_file" ]]; then
          target="$(cat "$target_path_file")"
          exec hx "$target"
        fi

        if [[ -s "$stderr_log" ]]; then
          cat "$stderr_log" >&2
        fi

        exit "$status"
      '';
    };

    settings = {
      gui.showCommandLog = false;
      promptToReturnFromSubprocess = false;
      os = {
        edit = ''${config.constructFiles.openInEditor.path} "{{filename}}"'';
        editAtLine = ''${config.constructFiles.openInEditor.path} "{{filename}}" "{{line}}"'';
      };
    };
  };
}
