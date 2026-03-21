{ lib, theme }:
''
    background ${theme.hex "base"}
    foreground ${theme.hex "text"}
    selection_background ${theme.hex "surface0"}
    selection_foreground ${theme.hex "text"}
    url_color ${theme.hex "teal"}
    cursor ${theme.hex "rosewater"}
    cursor_text_color ${theme.hex "base"}

    active_tab_background ${theme.hex theme.selection.accent}
    active_tab_foreground ${theme.hex "base"}
    inactive_tab_background ${theme.hex "surface1"}
    inactive_tab_foreground ${theme.hex "text"}

    active_border_color ${theme.hex theme.selection.accent}
    inactive_border_color ${theme.hex "surface1"}

    color0 ${theme.hex "crust"}
    color1 ${theme.hex "red"}
    color2 ${theme.hex "green"}
    color3 ${theme.hex "yellow"}
    color4 ${theme.hex "blue"}
    color5 ${theme.hex "mauve"}
    color6 ${theme.hex "teal"}
    color7 ${theme.hex "text"}

    color8 ${theme.hex "surface2"}
    color9 ${theme.hex "red"}
    color10 ${theme.hex "green"}
    color11 ${theme.hex "yellow"}
    color12 ${theme.hex "blue"}
    color13 ${theme.hex "mauve"}
    color14 ${theme.hex "teal"}
    color15 ${theme.hex "rosewater"}

    color16 ${theme.hex "peach"}
    color17 ${theme.hex "maroon"}
  ''
