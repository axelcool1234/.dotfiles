{
  hostVars,
  lib,
  pkgs,
  ...
}:
let
  editorSupportsLine = hostVars.editor == "neovim";
  remoteOpenScript = pkgs.writeShellScript "jjui-open-in-neovim" ''
    set -eu

    server=$1
    progpath=$2
    path=$3
    line=''${4:-1}

    if [ -z "$server" ] || [ -z "$progpath" ] || [ -z "$path" ]; then
      exit 1
    fi

    case "$line" in
      ""|*[!0-9]*)
        line=1
        ;;
    esac

    lua_quote() {
      value=$1
      equals=

      while :; do
        close="]''${equals}]"
        case "$value" in
          *"$close"*)
            equals="''${equals}="
            ;;
          *)
            printf '[%s[%s]%s]' "$equals" "$value" "$equals"
            return
            ;;
        esac
      done
    }

    exec "$progpath" \
      --server "$server" \
      --remote-send "<Cmd>lua require('axelcool1234.jjui').open_target($(lua_quote "$path"), $line)<CR>"
  '';
in
{
  imports = [ ./module.nix ];

  config = {
    settings = {
      actions = [
        {
          name = "open-in-editor";
          desc = "open file in editor";
          lua = ''
            local function first_hunk_new_lineno(git_diff)
              if not git_diff then
                return nil
              end

              for line in git_diff:gmatch("[^\n]+") do
                if line:sub(1, 3) == "@@ " then
                  local new_start = line:match("%+(%d+)")
                  if new_start then
                    return tonumber(new_start)
                  end
                end
              end

              return nil
            end

            local file = context.file()
            if not file or file == "" then
              flash({ text = "No file selected", error = true })
              return
            end

            local change_id = context.change_id()
            if not change_id or change_id == "" then
              flash({ text = "No revision selected", error = true })
              return
            end

            local diff = jj("diff", "--git", "-r", change_id, file)
            local line_number = first_hunk_new_lineno(diff)

            local _, edit_err = jj("edit", change_id)
            if edit_err then
              flash({ text = "Failed to edit revision: " .. tostring(edit_err), error = true })
              return
            end

            local nvim_server = os.getenv("JJUI_NVIM_SERVER")
            local nvim_progpath = os.getenv("JJUI_NVIM_PROGPATH")

            if nvim_server and nvim_server ~= "" and nvim_progpath and nvim_progpath ~= "" then
              exec_shell(string.format("%q %q %q %q %d", "${remoteOpenScript}", nvim_server, nvim_progpath, file, line_number or 1))
              return
            end

            local editor = os.getenv("VISUAL") or os.getenv("EDITOR")

            if not editor or editor == "" then
              flash({ text = "Set VISUAL or EDITOR to open files", error = true })
              return
            end

            if ${if editorSupportsLine then "true" else "false"} and line_number then
              exec_shell(string.format("%q +%d %q", editor, line_number, file))
              jjui.ui.quit()
              return
            end

            exec_shell(string.format("%q %q", editor, file))
            jjui.ui.quit()
          '';
        }
      ];

      bindings = [
        {
          action = "ui.preview_expand";
          key = "ctrl+,";
          scope = "ui.preview";
          desc = "expand preview";
        }
        {
          action = "ui.preview_shrink";
          key = "ctrl+.";
          scope = "ui.preview";
          desc = "shrink preview";
        }
        {
          action = "ui.cancel";
          key = "d";
          scope = "diff";
          desc = "cancel";
        }
        {
          action = "open-in-editor";
          key = "e";
          scope = "revisions.details";
          desc = "edit file";
        }
        {
          action = "open-in-editor";
          key = "e";
          scope = "file_search";
          desc = "edit file";
        }
        {
          action = "open-in-editor";
          key = "e";
          scope = "diff";
          desc = "edit file";
        }
      ];

      preview = {
        show_at_start = true;
        position = "right";
        revision_command = [
          "show"
          "-r"
          "$change_id"
          "--summary"
          "--git"
          "--color"
          "always"
        ];
      };

      suggest.exec.mode = "fuzzy";
    };
  };
}
