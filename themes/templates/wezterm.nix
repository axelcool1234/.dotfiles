{ lib, theme }:
''
    return {
      foreground = "${theme.hex "text"}",
      background = "${theme.hex "base"}",
      cursor_bg = "${theme.hex "rosewater"}",
      cursor_fg = "${theme.hex "base"}",
      cursor_border = "${theme.hex "rosewater"}",
      selection_bg = "${theme.hex "surface0"}",
      selection_fg = "${theme.hex "text"}",
      ansi = {
        "${theme.hex "crust"}",
        "${theme.hex "red"}",
        "${theme.hex "green"}",
        "${theme.hex "yellow"}",
        "${theme.hex "blue"}",
        "${theme.hex "mauve"}",
        "${theme.hex "teal"}",
        "${theme.hex "text"}",
      },
      brights = {
        "${theme.hex "surface2"}",
        "${theme.hex "red"}",
        "${theme.hex "green"}",
        "${theme.hex "yellow"}",
        "${theme.hex "blue"}",
        "${theme.hex "mauve"}",
        "${theme.hex "teal"}",
        "${theme.hex "rosewater"}",
      },
      tab_bar = {
        background = "${theme.hex "mantle"}",
        active_tab = {
          bg_color = "${theme.hex theme.selection.accent}",
          fg_color = "${theme.hex "base"}",
        },
        inactive_tab = {
          bg_color = "${theme.hex "surface1"}",
          fg_color = "${theme.hex "text"}",
        },
      },
    }
  ''
