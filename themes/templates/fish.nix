{ lib, theme }:
''
    set -g fish_color_autosuggestion "${theme.hex "overlay0"}"
    set -g fish_color_cancel "${theme.hex "red"}"
    set -g fish_color_command "${theme.hex "blue"}"
    set -g fish_color_comment "${theme.hex "overlay1"}"
    set -g fish_color_cwd "${theme.hex "green"}"
    set -g fish_color_cwd_root "${theme.hex "red"}"
    set -g fish_color_end "${theme.hex "teal"}"
    set -g fish_color_error "${theme.hex "red"}"
    set -g fish_color_escape "${theme.hex "pink"}"
    set -g fish_color_history_current --bold
    set -g fish_color_host "${theme.hex "text"}"
    set -g fish_color_host_remote "${theme.hex "yellow"}"
    set -g fish_color_normal "${theme.hex "text"}"
    set -g fish_color_operator "${theme.hex "sky"}"
    set -g fish_color_param "${theme.hex "text"}"
    set -g fish_color_quote "${theme.hex "green"}"
    set -g fish_color_redirection "${theme.hex "teal"}"
    set -g fish_color_search_match "--background=${theme.hex "surface0"}"
    set -g fish_color_selection "--background=${theme.hex "surface0"}"
    set -g fish_color_status "${theme.hex "red"}"
    set -g fish_color_user "${theme.hex "mauve"}"
    set -g fish_color_valid_path --underline
    set -g fish_pager_color_completion "${theme.hex "text"}"
    set -g fish_pager_color_description "${theme.hex "yellow"}"
    set -g fish_pager_color_prefix "${theme.hex "sky"}" --bold --underline
    set -g fish_pager_color_progress "${theme.hex "text"}" "--background=${theme.hex "surface0"}"
    set -g fish_pager_color_selected_background "${theme.hex "surface0"}"
  ''
