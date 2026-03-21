{ lib, theme }:
''
    set default-fg                "${theme.hex "text"}"
    set default-bg                "${theme.hex "base"}"

    set completion-bg             "${theme.hex "surface0"}"
    set completion-fg             "${theme.hex "text"}"
    set completion-highlight-bg   "${theme.hex "surface1"}"
    set completion-highlight-fg   "${theme.hex "text"}"
    set completion-group-bg       "${theme.hex "surface0"}"
    set completion-group-fg       "${theme.hex "blue"}"

    set statusbar-fg              "${theme.hex "text"}"
    set statusbar-bg              "${theme.hex "surface0"}"

    set notification-bg           "${theme.hex "surface0"}"
    set notification-fg           "${theme.hex "text"}"
    set notification-error-bg     "${theme.hex "surface0"}"
    set notification-error-fg     "${theme.hex "red"}"
    set notification-warning-bg   "${theme.hex "surface0"}"
    set notification-warning-fg   "${theme.hex "yellow"}"

    set inputbar-fg               "${theme.hex "text"}"
    set inputbar-bg               "${theme.hex "surface0"}"

    set recolor-lightcolor        "${theme.hex "base"}"
    set recolor-darkcolor         "${theme.hex "text"}"

    set index-fg                  "${theme.hex "text"}"
    set index-bg                  "${theme.hex "base"}"
    set index-active-fg           "${theme.hex "text"}"
    set index-active-bg           "${theme.hex "surface0"}"

    set render-loading-bg         "${theme.hex "base"}"
    set render-loading-fg         "${theme.hex "text"}"

    set highlight-color           "${theme.zathura.highlight}"
    set highlight-fg              "${theme.zathura.highlightForeground}"
    set highlight-active-color    "${theme.zathura.highlightForeground}"
  ''
