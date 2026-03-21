{ lib, theme }:
let
  paletteNames = [
    "rosewater"
    "flamingo"
    "pink"
    "mauve"
    "red"
    "maroon"
    "peach"
    "yellow"
    "green"
    "teal"
    "sky"
    "sapphire"
    "blue"
    "lavender"
    "text"
    "subtext1"
    "subtext0"
    "overlay2"
    "overlay1"
    "overlay0"
    "surface2"
    "surface1"
    "surface0"
    "base"
    "mantle"
    "crust"
  ];


  hyprlandColors =
    lib.concatStringsSep "\n\n"
      (map (name: ''
        ${"$" + name} = rgb(${theme.palette.${name}})
        ${"$" + name}Alpha = ${theme.palette.${name}}
      '') paletteNames);

  waybarPalette = lib.concatStringsSep "\n"
    (map (name: "@define-color ${name} ${theme.hex name};") [
      "base"
      "mantle"
      "crust"
      "text"
      "subtext0"
      "subtext1"
      "surface0"
      "surface1"
      "surface2"
      "overlay0"
      "overlay1"
      "overlay2"
      "blue"
      "lavender"
      "sapphire"
      "sky"
      "teal"
      "green"
      "yellow"
      "peach"
      "maroon"
      "red"
      "mauve"
      "pink"
      "flamingo"
      "rosewater"
    ]);

  discordMode = theme.discord.mode;
  yaziSyntectThemeFileName = "${theme.selection.family}-${theme.selection.flavor}.tmTheme";
in
{
  inherit yaziSyntectThemeFileName;

  hyprland = ''
    ${hyprlandColors}

    env = HYPRCURSOR_THEME,${theme.cursor.name}
    env = HYPRCURSOR_SIZE,${toString theme.cursor.size}
    env = XCURSOR_THEME,${theme.cursor.name}
    env = XCURSOR_SIZE,${toString theme.cursor.size}
  '';

  waybar = waybarPalette;

  kitty = ''
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
  '';

  wezterm = ''
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
  '';

  helix = ''
    # Syntax highlighting
    # -------------------
    "attribute" = "yellow"

    "type" = "yellow"
    "type.builtin" = "mauve"
    "type.enum.variant" = "teal"

    "constructor" = "sapphire"

    "constant" = "peach"
    "constant.character" = "teal"
    "constant.character.escape" = "pink"

    "string" = "green"
    "string.regexp" = "pink"
    "string.special" = "blue"
    "string.special.symbol" = "red"

    "comment" = { fg = "overlay2", modifiers = ["italic"] }

    "variable" = "text"
    "variable.parameter" = { fg = "maroon", modifiers = ["italic"] }
    "variable.builtin" = "red"
    "variable.other.member" = "blue"

    "label" = "sapphire"

    "punctuation" = "overlay2"
    "punctuation.special" = "sky"

    "keyword" = "mauve"
    "keyword.control.conditional" = { fg = "mauve", modifiers = ["italic"] }

    "operator" = "sky"

    "function" = "blue"
    "function.macro" = "rosewater"

    "tag" = "blue"

    "namespace" = { fg = "yellow", modifiers = ["italic"] }

    "special" = "blue"

    "markup.heading.1" = "red"
    "markup.heading.2" = "peach"
    "markup.heading.3" = "yellow"
    "markup.heading.4" = "green"
    "markup.heading.5" = "sapphire"
    "markup.heading.6" = "lavender"
    "markup.list" = "teal"
    "markup.list.unchecked" = "overlay2"
    "markup.list.checked" = "green"
    "markup.bold" = { fg = "red", modifiers = ["bold"] }
    "markup.italic" = { fg = "red", modifiers = ["italic"] }
    "markup.strikethrough" = { modifiers = ["crossed_out"] }
    "markup.link.url" = { fg = "blue", modifiers = ["italic", "underlined"] }
    "markup.link.text" = "lavender"
    "markup.link.label" = "sapphire"
    "markup.raw" = "green"
    "markup.quote" = "pink"

    "diff.plus" = "green"
    "diff.minus" = "red"
    "diff.delta" = "blue"

    # User interface
    # --------------
    "ui.background" = { fg = "text", bg = "base" }

    "ui.linenr" = { fg = "surface1" }
    "ui.linenr.selected" = { fg = "lavender" }

    "ui.statusline" = { fg = "subtext1", bg = "mantle" }
    "ui.statusline.inactive" = { fg = "surface2", bg = "mantle" }
    "ui.statusline.normal" = { fg = "base", bg = "rosewater", modifiers = ["bold"] }
    "ui.statusline.insert" = { fg = "base", bg = "green", modifiers = ["bold"] }
    "ui.statusline.select" = { fg = "base", bg = "lavender", modifiers = ["bold"] }

    "ui.popup" = { fg = "text", bg = "surface0" }
    "ui.window" = { fg = "crust" }
    "ui.help" = { fg = "overlay2", bg = "surface0" }

    "ui.bufferline" = { fg = "subtext0", bg = "mantle" }
    "ui.bufferline.active" = { fg = "mauve", bg = "base", underline = { color = "mauve", style = "line" } }
    "ui.bufferline.background" = { bg = "crust" }

    "ui.text" = "text"
    "ui.text.focus" = { fg = "text", bg = "surface0", modifiers = ["bold"] }
    "ui.text.inactive" = { fg = "overlay1" }
    "ui.text.directory" = { fg = "blue" }

    "ui.virtual" = "overlay0"
    "ui.virtual.ruler" = { bg = "surface0" }
    "ui.virtual.indent-guide" = "surface0"
    "ui.virtual.inlay-hint" = { fg = "surface1", bg = "mantle" }
    "ui.virtual.jump-label" = { fg = "rosewater", modifiers = ["bold"] }

    "ui.selection" = { bg = "surface1" }

    "ui.cursor" = { fg = "base", bg = "secondary_cursor" }
    "ui.cursor.primary" = { fg = "base", bg = "rosewater" }
    "ui.cursor.match" = { fg = "peach", modifiers = ["bold"] }

    "ui.cursor.primary.normal" = { fg = "base", bg = "rosewater" }
    "ui.cursor.primary.insert" = { fg = "base", bg = "green" }
    "ui.cursor.primary.select" = { fg = "base", bg = "lavender" }

    "ui.cursor.normal" = { fg = "base", bg = "secondary_cursor_normal" }
    "ui.cursor.insert" = { fg = "base", bg = "secondary_cursor_insert" }
    "ui.cursor.select" = { fg = "base", bg = "secondary_cursor_select" }

    "ui.cursorline.primary" = { bg = "cursorline" }

    "ui.highlight" = { bg = "surface1", modifiers = ["bold"] }

    "ui.menu" = { fg = "overlay2", bg = "surface0" }
    "ui.menu.selected" = { fg = "text", bg = "surface1", modifiers = ["bold"] }

    "diagnostic.error" = { underline = { color = "red", style = "curl" } }
    "diagnostic.warning" = { underline = { color = "yellow", style = "curl" } }
    "diagnostic.info" = { underline = { color = "sky", style = "curl" } }
    "diagnostic.hint" = { underline = { color = "teal", style = "curl" } }
    "diagnostic.unnecessary" = { modifiers = ["dim"] }
    "diagnostic.deprecated" = { modifiers = ["crossed_out"] }

    error = "red"
    warning = "yellow"
    info = "sky"
    hint = "teal"

    rainbow = ["red", "peach", "yellow", "green", "sapphire", "lavender"]

    [palette]
    rosewater = "${theme.hex "rosewater"}"
    flamingo = "${theme.hex "flamingo"}"
    pink = "${theme.hex "pink"}"
    mauve = "${theme.hex "mauve"}"
    red = "${theme.hex "red"}"
    maroon = "${theme.hex "maroon"}"
    peach = "${theme.hex "peach"}"
    yellow = "${theme.hex "yellow"}"
    green = "${theme.hex "green"}"
    teal = "${theme.hex "teal"}"
    sky = "${theme.hex "sky"}"
    sapphire = "${theme.hex "sapphire"}"
    blue = "${theme.hex "blue"}"
    lavender = "${theme.hex "lavender"}"
    text = "${theme.hex "text"}"
    subtext1 = "${theme.hex "subtext1"}"
    subtext0 = "${theme.hex "subtext0"}"
    overlay2 = "${theme.hex "overlay2"}"
    overlay1 = "${theme.hex "overlay1"}"
    overlay0 = "${theme.hex "overlay0"}"
    surface2 = "${theme.hex "surface2"}"
    surface1 = "${theme.hex "surface1"}"
    surface0 = "${theme.hex "surface0"}"
    base = "${theme.hex "base"}"
    mantle = "${theme.hex "mantle"}"
    crust = "${theme.hex "crust"}"

    # Extra palette entries used by this Helix alone.
    cursorline = "${theme.hex "helix.cursorline"}"
    secondary_cursor = "${theme.hex "helix.secondary_cursor"}"
    secondary_cursor_select = "${theme.hex "helix.secondary_cursor_select"}"
    secondary_cursor_normal = "${theme.hex "helix.secondary_cursor_normal"}"
    secondary_cursor_insert = "${theme.hex "helix.secondary_cursor_insert"}"
  '';

  fish = ''
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
  '';

  rofi = ''
    * {
        bg-col:  ${theme.hex "base"};
        bg-col-light: ${theme.hex "base"};
        border-col: ${theme.hex "base"};
        selected-col: ${theme.hex "base"};
        blue: ${theme.hex "blue"};
        fg-col: ${theme.hex "text"};
        fg-col2: ${theme.hex "red"};
        grey: ${theme.hex "overlay0"};
        teal: ${theme.hex "teal"};

        width: 600;
        border-radius: 15px;
    }

    element-text, element-icon , mode-switcher {
        background-color: inherit;
        text-color:       inherit;
    }

    window {
        height: 360px;
        border: 2px;
        border-color: @teal;
        background-color: @bg-col;
    }

    mainbox {
        background-color: @bg-col;
    }

    inputbar {
        children: [prompt,entry];
        background-color: @bg-col;
        border-radius: 5px;
        padding: 2px;
    }

    prompt {
        background-color: @blue;
        padding: 6px;
        text-color: @bg-col;
        border-radius: 3px;
        margin: 20px 0px 0px 20px;
    }

    textbox-prompt-colon {
        expand: false;
        str: ":";
    }

    entry {
        padding: 6px;
        margin: 20px 0px 0px 10px;
        text-color: @fg-col;
        background-color: @bg-col;
    }

    listview {
        border: 0px 0px 0px;
        padding: 6px 0px 0px;
        margin: 10px 0px 0px 20px;
        columns: 2;
        lines: 5;
        background-color: @bg-col;
    }

    element {
        padding: 5px;
        background-color: @bg-col;
        text-color: @fg-col;
    }

    element-icon {
        size: 25px;
    }

    element selected {
        background-color: @selected-col;
        text-color: @teal;
    }

    mode-switcher {
        spacing: 0;
    }

    button {
        padding: 10px;
        background-color: @bg-col-light;
        text-color: @grey;
        vertical-align: 0.5;
        horizontal-align: 0.5;
    }

    button selected {
        background-color: @bg-col;
        text-color: @blue;
    }

    message {
        background-color: @bg-col-light;
        margin: 2px;
        padding: 2px;
        border-radius: 5px;
    }

    textbox {
        padding: 6px;
        margin: 20px 0px 0px 20px;
        text-color: @blue;
        background-color: @bg-col-light;
    }
  '';

  wlogout = ''
    @define-color overlay ${theme.rgba "base" 0.7};
    @define-color text ${theme.hex "text"};
    @define-color surface0 ${theme.hex "surface0"};
    @define-color base ${theme.hex "base"};
    @define-color accent ${theme.hex theme.selection.accent};
  '';

  zathura = ''
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
  '';

  nushell = ''
    let theme = {
      rosewater: "${theme.hex "rosewater"}"
      flamingo: "${theme.hex "flamingo"}"
      pink: "${theme.hex "pink"}"
      mauve: "${theme.hex "mauve"}"
      red: "${theme.hex "red"}"
      maroon: "${theme.hex "maroon"}"
      peach: "${theme.hex "peach"}"
      yellow: "${theme.hex "yellow"}"
      green: "${theme.hex "green"}"
      teal: "${theme.hex "teal"}"
      sky: "${theme.hex "sky"}"
      sapphire: "${theme.hex "sapphire"}"
      blue: "${theme.hex "blue"}"
      lavender: "${theme.hex "lavender"}"
      text: "${theme.hex "text"}"
      subtext1: "${theme.hex "subtext1"}"
      subtext0: "${theme.hex "subtext0"}"
      overlay2: "${theme.hex "overlay2"}"
      overlay1: "${theme.hex "overlay1"}"
      overlay0: "${theme.hex "overlay0"}"
      surface2: "${theme.hex "surface2"}"
      surface1: "${theme.hex "surface1"}"
      surface0: "${theme.hex "surface0"}"
      base: "${theme.hex "base"}"
      mantle: "${theme.hex "mantle"}"
      crust: "${theme.hex "crust"}"
    }

    let scheme = {
      recognized_command: $theme.blue
      unrecognized_command: $theme.text
      constant: $theme.peach
      punctuation: $theme.overlay2
      operator: $theme.sky
      string: $theme.green
      virtual_text: $theme.surface2
      variable: { fg: $theme.flamingo attr: i }
      filepath: $theme.yellow
    }

    $env.config.color_config = {
      separator: { fg: $theme.surface2 attr: b }
      leading_trailing_space_bg: { fg: $theme.lavender attr: u }
      header: { fg: $theme.text attr: b }
      row_index: $scheme.virtual_text
      record: $theme.text
      list: $theme.text
      hints: $scheme.virtual_text
      search_result: { fg: $theme.base bg: $theme.yellow }
      shape_closure: $theme.teal
      closure: $theme.teal
      shape_flag: { fg: $theme.maroon attr: i }
      shape_matching_brackets: { attr: u }
      shape_garbage: $theme.red
      shape_keyword: $theme.mauve
      shape_match_pattern: $theme.green
      shape_signature: $theme.teal
      shape_table: $scheme.punctuation
      cell-path: $scheme.punctuation
      shape_list: $scheme.punctuation
      shape_record: $scheme.punctuation
      shape_vardecl: $scheme.variable
      shape_variable: $scheme.variable
      empty: { attr: n }
      filesize: {||
        if $in < 1kb { $theme.teal } else if $in < 10kb { $theme.green } else if $in < 100kb { $theme.yellow } else if $in < 10mb { $theme.peach } else if $in < 100mb { $theme.maroon } else if $in < 1gb { $theme.red } else { $theme.mauve }
      }
      duration: {||
        if $in < 1day { $theme.teal } else if $in < 1wk { $theme.green } else if $in < 4wk { $theme.yellow } else if $in < 12wk { $theme.peach } else if $in < 24wk { $theme.maroon } else if $in < 52wk { $theme.red } else { $theme.mauve }
      }
      date: {|| (date now) - $in |
        if $in < 1day { $theme.teal } else if $in < 1wk { $theme.green } else if $in < 4wk { $theme.yellow } else if $in < 12wk { $theme.peach } else if $in < 24wk { $theme.maroon } else if $in < 52wk { $theme.red } else { $theme.mauve }
      }
      shape_external: $scheme.unrecognized_command
      shape_internalcall: $scheme.recognized_command
      shape_external_resolved: $scheme.recognized_command
      shape_block: $scheme.recognized_command
      block: $scheme.recognized_command
      shape_custom: $theme.pink
      custom: $theme.pink
      background: $theme.base
      foreground: $theme.text
      cursor: { bg: $theme.rosewater fg: $theme.base }
      shape_range: $scheme.operator
      range: $scheme.operator
      shape_pipe: $scheme.operator
      shape_operator: $scheme.operator
      shape_redirection: $scheme.operator
      glob: $scheme.filepath
      shape_directory: $scheme.filepath
      shape_filepath: $scheme.filepath
      shape_glob_interpolation: $scheme.filepath
      shape_globpattern: $scheme.filepath
      shape_int: $scheme.constant
      int: $scheme.constant
      bool: $scheme.constant
      float: $scheme.constant
      nothing: $scheme.constant
      binary: $scheme.constant
      shape_nothing: $scheme.constant
      shape_bool: $scheme.constant
      shape_float: $scheme.constant
      shape_binary: $scheme.constant
      shape_datetime: $scheme.constant
      shape_literal: $scheme.constant
      string: $scheme.string
      shape_string: $scheme.string
      shape_string_interpolation: $theme.flamingo
      shape_raw_string: $scheme.string
      shape_externalarg: $scheme.string
    }
    $env.config.highlight_resolved_externals = true
    $env.config.explore = {
      status_bar_background: { fg: $theme.text, bg: $theme.mantle }
      command_bar_text: { fg: $theme.text }
      highlight: { fg: $theme.base, bg: $theme.yellow }
      status: {
        error: $theme.red
        warn: $theme.yellow
        info: $theme.blue
      }
      selected_cell: { bg: $theme.blue fg: $theme.base }
    }
  '';

  btop = ''
    theme[main_bg]="${theme.hex "base"}"
    theme[main_fg]="${theme.hex "text"}"
    theme[title]="${theme.hex "text"}"
    theme[hi_fg]="${theme.hex "blue"}"
    theme[selected_bg]="${theme.hex "surface1"}"
    theme[selected_fg]="${theme.hex "blue"}"
    theme[inactive_fg]="${theme.hex "overlay1"}"
    theme[graph_text]="${theme.hex "rosewater"}"
    theme[meter_bg]="${theme.hex "surface1"}"
    theme[proc_misc]="${theme.hex "rosewater"}"
    theme[cpu_box]="${theme.hex "sapphire"}"
    theme[mem_box]="${theme.hex "green"}"
    theme[net_box]="${theme.hex "mauve"}"
    theme[proc_box]="${theme.hex "flamingo"}"
    theme[div_line]="${theme.hex "overlay0"}"
    theme[temp_start]="${theme.hex "yellow"}"
    theme[temp_mid]="${theme.hex "peach"}"
    theme[temp_end]="${theme.hex "red"}"
    theme[cpu_start]="${theme.hex "sapphire"}"
    theme[cpu_mid]="${theme.hex "sky"}"
    theme[cpu_end]="${theme.hex "teal"}"
    theme[free_start]="${theme.hex "teal"}"
    theme[free_mid]="${theme.hex "teal"}"
    theme[free_end]="${theme.hex "green"}"
    theme[cached_start]="${theme.hex "pink"}"
    theme[cached_mid]="${theme.hex "pink"}"
    theme[cached_end]="${theme.hex "mauve"}"
    theme[available_start]="${theme.hex "rosewater"}"
    theme[available_mid]="${theme.hex "flamingo"}"
    theme[available_end]="${theme.hex "flamingo"}"
    theme[used_start]="${theme.hex "peach"}"
    theme[used_mid]="${theme.hex "peach"}"
    theme[used_end]="${theme.hex "red"}"
    theme[download_start]="${theme.hex "lavender"}"
    theme[download_mid]="${theme.hex "lavender"}"
    theme[download_end]="${theme.hex "mauve"}"
    theme[upload_start]="${theme.hex "lavender"}"
    theme[upload_mid]="${theme.hex "lavender"}"
    theme[upload_end]="${theme.hex "mauve"}"
    theme[process_start]="${theme.hex "sapphire"}"
    theme[process_mid]="${theme.hex "sky"}"
    theme[process_end]="${theme.hex "teal"}"
  '';

  discord = ''
    .theme-${discordMode},
    .visual-refresh.theme-${discordMode},
    .visual-refresh .theme-${discordMode} {
      --brand-500: ${theme.hex (theme.selection.accent)} !important;
      --brand-530: ${theme.hex (theme.selection.accent)};
      --brand-560: ${theme.hex (theme.selection.accent)};
      --blurple-50: ${theme.hex (theme.selection.accent)};
      --text-default: ${theme.hex "text"};
      --text-muted: ${theme.hex "subtext0"} !important;
      --text-link: ${theme.hex (theme.selection.accent)} !important;
      --text-brand: ${theme.hex (theme.selection.accent)};
      --text-strong: ${theme.hex "text"} !important;
      --text-subtle: ${theme.hex "subtext1"};
      --text-feedback-positive: ${theme.hex "green"};
      --text-feedback-critical: ${theme.hex "red"};
      --text-feedback-warning: ${theme.hex "yellow"};
      --text-feedback-info: ${theme.hex "sky"};
      --app-frame-background: ${theme.hex "crust"};
      --background-primary: ${theme.hex "base"};
      --background-secondary: ${theme.hex "mantle"};
      --background-secondary-alt: ${theme.hex "mantle"} !important;
      --background-tertiary: ${theme.hex "crust"};
      --background-accent: ${theme.hex "surface1"} !important;
      --background-floating: ${theme.hex "mantle"};
      --background-modifier-hover: ${theme.rgba "surface2" 0.15};
      --background-modifier-active: ${theme.rgba "surface2" 0.25};
      --background-modifier-selected: ${theme.rgba "surface2" 0.45};
      --background-mentioned: ${theme.rgba "yellow" 0.1};
      --background-mentioned-hover: ${theme.rgba "yellow" 0.08};
      --background-message-hover: ${theme.rgba "crust" 0.3};
      --background-message-highlight: ${theme.rgba theme.selection.accent 0.3};
      --background-base-lowest: ${theme.hex "crust"} !important;
      --background-base-lower: ${theme.hex "mantle"} !important;
      --background-base-low: ${theme.hex "surface0"} !important;
      --background-surface-high: ${theme.hex "base"} !important;
      --background-surface-higher: ${theme.hex "surface0"} !important;
      --background-surface-highest: ${theme.hex "surface1"} !important;
      --background-code: ${theme.hex "base"};
      --chat-background: ${theme.hex "base"};
      --chat-background-default: ${theme.hex "base"};
      --chat-border: ${theme.hex "crust"};
      --channeltextarea-background: ${theme.hex "mantle"};
      --input-background: ${theme.hex "crust"};
      --input-placeholder-text-default: ${theme.hex "subtext1"};
      --input-border-default: ${theme.hex "overlay0"};
      --modal-background: ${theme.hex "base"} !important;
      --modal-footer-background: ${theme.hex "mantle"};
      --scrollbar-thin-thumb: ${theme.hex (theme.selection.accent)};
      --scrollbar-auto-thumb: ${theme.hex (theme.selection.accent)};
      --scrollbar-auto-track: ${theme.hex "crust"};
      --scrollbar-auto-scrollbar-color-thumb: ${theme.hex (theme.selection.accent)};
      --scrollbar-auto-scrollbar-color-track: ${theme.hex "crust"};
      --button-secondary-background: ${theme.hex "surface1"};
      --button-secondary-background-hover: ${theme.hex "surface2"};
      --button-secondary-background-active: ${theme.hex "surface0"};
      --interactive-normal: ${theme.hex "text"};
      --interactive-hover: ${theme.hex "text"};
      --interactive-active: ${theme.hex "text"};
      --interactive-muted: ${theme.hex "overlay0"};
      --channels-default: ${theme.hex "subtext1"} !important;
      --channel-icon: ${theme.hex "subtext1"} !important;
      --channel-text-area-placeholder: ${theme.hex "subtext0"};
      --header-primary: ${theme.hex "text"};
      --header-secondary: ${theme.hex "subtext1"};
      --logo-primary: ${theme.hex "text"};
      --mention-foreground: ${theme.hex (theme.selection.accent)};
      --message-reacted-background-default: ${theme.rgba (theme.selection.accent) 0.3} !important;
      --message-reacted-text-default: ${theme.hex (theme.selection.accent)};
      --background-feedback-positive: ${theme.rgba "green" 0.15};
      --background-feedback-warning: ${theme.rgba "yellow" 0.15};
      --background-feedback-critical: ${theme.rgba "red" 0.15};
      --background-feedback-info: ${theme.rgba "sky" 0.15};
      --background-feedback-notification: ${theme.hex "red"};
      --status-positive: ${theme.hex "green"};
      --status-warning: ${theme.hex "yellow"};
      --status-danger: ${theme.hex "red"};
      --status-positive-background: ${theme.hex "green"};
      --status-warning-background: ${theme.hex "yellow"};
      --status-danger-background: ${theme.hex "red"};
      --status-positive-text: ${theme.hex "base"};
      --status-warning-text: ${theme.hex "base"};
      --status-danger-text: ${theme.hex "base"};
      --spoiler-hidden-background: ${theme.hex "surface2"};
      --spoiler-revealed-background: ${theme.hex "surface0"};
      --border-subtle: ${theme.hex "base"} !important;
      --border-normal: ${theme.hex "crust"};
      --border-strong: ${theme.hex "mantle"};
      --custom-channel-members-bg: ${theme.hex "mantle"};
      --custom-status-bubble-background: ${theme.hex "crust"} !important;
      --custom-status-bubble-background-color: ${theme.hex "mantle"} !important;
      --card-background-filled: ${theme.hex "surface0"};
      --notice-background-positive: ${theme.hex "green"};
      --notice-background-warning: ${theme.hex "yellow"};
      --notice-background-critical: ${theme.hex "red"};
      --notice-background-info: ${theme.hex "sky"};
      --notice-text-positive: ${theme.hex "base"};
      --notice-text-warning: ${theme.hex "base"};
      --notice-text-critical: ${theme.hex "base"};
      --notice-text-info: ${theme.hex "base"};
    }

    .theme-${discordMode} ::selection,
    .visual-refresh.theme-${discordMode} ::selection,
    .visual-refresh .theme-${discordMode} ::selection {
      background-color: ${theme.rgba (theme.selection.accent) 0.6};
    }

    .theme-${discordMode} button[class*=colorBrand_],
    .visual-refresh.theme-${discordMode} button[class*=colorBrand_],
    .visual-refresh .theme-${discordMode} button[class*=colorBrand_] {
      background-color: ${theme.hex (theme.selection.accent)} !important;
      color: ${theme.hex "base"} !important;
    }

    .theme-${discordMode} button[class*=colorBrand_]:hover,
    .visual-refresh.theme-${discordMode} button[class*=colorBrand_]:hover,
    .visual-refresh .theme-${discordMode} button[class*=colorBrand_]:hover {
      filter: brightness(1.08);
    }

    .theme-${discordMode} [class*=panels_],
    .theme-${discordMode} [class*=sidebar_],
    .theme-${discordMode} [class*=membersWrap_],
    .theme-${discordMode} [class*=container_][class*=themed_],
    .visual-refresh.theme-${discordMode} [class*=panels_],
    .visual-refresh.theme-${discordMode} [class*=sidebar_],
    .visual-refresh.theme-${discordMode} [class*=membersWrap_],
    .visual-refresh.theme-${discordMode} [class*=container_][class*=themed_] {
      background: ${theme.hex "mantle"} !important;
    }
  '';

  yazi = ''
    [mgr]
    cwd = { fg = "${theme.hex "teal"}" }

    hovered         = { fg = "${theme.hex "base"}", bg = "${theme.hex "blue"}" }
    preview_hovered = { fg = "${theme.hex "base"}", bg = "${theme.hex "text"}" }

    find_keyword  = { fg = "${theme.hex "yellow"}", italic = true }
    find_position = { fg = "${theme.hex "pink"}", bg = "reset", italic = true }

    marker_copied   = { fg = "${theme.hex "green"}", bg = "${theme.hex "green"}" }
    marker_cut      = { fg = "${theme.hex "red"}", bg = "${theme.hex "red"}" }
    marker_marked   = { fg = "${theme.hex "teal"}", bg = "${theme.hex "teal"}" }
    marker_selected = { fg = "${theme.hex "blue"}", bg = "${theme.hex "blue"}" }

    count_copied   = { fg = "${theme.hex "base"}", bg = "${theme.hex "green"}" }
    count_cut      = { fg = "${theme.hex "base"}", bg = "${theme.hex "red"}" }
    count_selected = { fg = "${theme.hex "base"}", bg = "${theme.hex "blue"}" }

    border_symbol = "│"
    border_style  = { fg = "${theme.hex "overlay1"}" }

    syntect_theme = "./${yaziSyntectThemeFileName}"

    [tabs]
    active   = { fg = "${theme.hex "base"}", bg = "${theme.hex "text"}", bold = true }
    inactive = { fg = "${theme.hex "text"}", bg = "${theme.hex "surface1"}" }

    [mode]
    normal_main = { fg = "${theme.hex "base"}", bg = "${theme.hex "blue"}", bold = true }
    normal_alt  = { fg = "${theme.hex "blue"}", bg = "${theme.hex "surface0"}" }

    select_main = { fg = "${theme.hex "base"}", bg = "${theme.hex "green"}", bold = true }
    select_alt  = { fg = "${theme.hex "green"}", bg = "${theme.hex "surface0"}" }

    unset_main = { fg = "${theme.hex "base"}", bg = "${theme.hex "flamingo"}", bold = true }
    unset_alt  = { fg = "${theme.hex "flamingo"}", bg = "${theme.hex "surface0"}" }

    [status]
    sep_left  = { open = "", close = "" }
    sep_right = { open = "", close = "" }

    progress_label  = { fg = "#ffffff", bold = true }
    progress_normal = { fg = "${theme.hex "blue"}", bg = "${theme.hex "surface1"}" }
    progress_error  = { fg = "${theme.hex "red"}", bg = "${theme.hex "surface1"}" }

    perm_type  = { fg = "${theme.hex "blue"}" }
    perm_read  = { fg = "${theme.hex "yellow"}" }
    perm_write = { fg = "${theme.hex "red"}" }
    perm_exec  = { fg = "${theme.hex "green"}" }
    perm_sep   = { fg = "${theme.hex "overlay1"}" }

    [input]
    border   = { fg = "${theme.hex "blue"}" }
    title    = {}
    value    = {}
    selected = { reversed = true }

    [pick]
    border   = { fg = "${theme.hex "blue"}" }
    active   = { fg = "${theme.hex "pink"}" }
    inactive = {}

    [confirm]
    border  = { fg = "${theme.hex "blue"}" }
    title   = { fg = "${theme.hex "blue"}" }
    content = {}
    list    = {}
    btn_yes = { reversed = true }
    btn_no  = {}

    [cmp]
    border = { fg = "${theme.hex "blue"}" }

    [tasks]
    border  = { fg = "${theme.hex "blue"}" }
    title   = {}
    hovered = { underline = true }

    [which]
    mask            = { bg = "${theme.hex "surface0"}" }
    cand            = { fg = "${theme.hex "teal"}" }
    rest            = { fg = "${theme.hex "overlay2"}" }
    desc            = { fg = "${theme.hex "pink"}" }
    separator       = "  "
    separator_style = { fg = "${theme.hex "surface2"}" }

    [help]
    on      = { fg = "${theme.hex "teal"}" }
    run     = { fg = "${theme.hex "pink"}" }
    desc    = { fg = "${theme.hex "overlay2"}" }
    hovered = { bg = "${theme.hex "surface2"}", bold = true }
    footer  = { fg = "${theme.hex "text"}", bg = "${theme.hex "surface1"}" }

    [notify]
    title_info  = { fg = "${theme.hex "teal"}" }
    title_warn  = { fg = "${theme.hex "yellow"}" }
    title_error = { fg = "${theme.hex "red"}" }

[filetype]
rules = [
	# Media
	{ mime = "image/*", fg = "${theme.hex "teal"}" },
	{ mime = "{audio,video}/*", fg = "${theme.hex "yellow"}" },

	# Archives
	{ mime = "application/*zip", fg = "${theme.hex "pink"}" },
	{ mime = "application/x-{tar,bzip*,7z-compressed,xz,rar}", fg = "${theme.hex "pink"}" },

	# Documents
	{ mime = "application/{pdf,doc,rtf}", fg = "${theme.hex "green"}" },

	# Fallback
	{ name = "*", fg = "${theme.hex "text"}" },
	{ name = "*/", fg = "${theme.hex "blue"}" }
]

[spot]
border = { fg = "${theme.hex "blue"}" }
title  = { fg = "${theme.hex "blue"}" }
tbl_cell = { fg = "${theme.hex "blue"}", reversed = true }
tbl_col = { bold = true }

[icon]
files = [
  { name = "kritadisplayrc", text = "", fg = "${theme.hex "mauve"}" },
  { name = ".gtkrc-2.0", text = "", fg = "${theme.hex "rosewater"}" },
  { name = "bspwmrc", text = "", fg = "${theme.hex "mantle"}" },
  { name = "webpack", text = "󰜫", fg = "${theme.hex "sapphire"}" },
  { name = "tsconfig.json", text = "", fg = "${theme.hex "sapphire"}" },
  { name = ".vimrc", text = "", fg = "${theme.hex "green"}" },
  { name = "gemfile$", text = "", fg = "${theme.hex "crust"}" },
  { name = "xmobarrc", text = "", fg = "${theme.hex "red"}" },
  { name = "avif", text = "", fg = "${theme.hex "overlay1"}" },
  { name = "fp-info-cache", text = "", fg = "${theme.hex "rosewater"}" },
  { name = ".zshrc", text = "", fg = "${theme.hex "green"}" },
  { name = "robots.txt", text = "󰚩", fg = "${theme.hex "overlay0"}" },
  { name = "dockerfile", text = "󰡨", fg = "${theme.hex "blue"}" },
  { name = ".git-blame-ignore-revs", text = "", fg = "${theme.hex "peach"}" },
  { name = ".nvmrc", text = "", fg = "${theme.hex "green"}" },
  { name = "hyprpaper.conf", text = "", fg = "${theme.hex "teal"}" },
  { name = ".prettierignore", text = "", fg = "${theme.hex "blue"}" },
  { name = "rakefile", text = "", fg = "${theme.hex "crust"}" },
  { name = "code_of_conduct", text = "", fg = "${theme.hex "red"}" },
  { name = "cmakelists.txt", text = "", fg = "${theme.hex "text"}" },
  { name = ".env", text = "", fg = "${theme.hex "yellow"}" },
  { name = "copying.lesser", text = "", fg = "${theme.hex "yellow"}" },
  { name = "readme", text = "󰂺", fg = "${theme.hex "rosewater"}" },
  { name = "settings.gradle", text = "", fg = "${theme.hex "surface2"}" },
  { name = "gruntfile.coffee", text = "", fg = "${theme.hex "peach"}" },
  { name = ".eslintignore", text = "", fg = "${theme.hex "surface1"}" },
  { name = "kalgebrarc", text = "", fg = "${theme.hex "blue"}" },
  { name = "kdenliverc", text = "", fg = "${theme.hex "blue"}" },
  { name = ".prettierrc.cjs", text = "", fg = "${theme.hex "blue"}" },
  { name = "cantorrc", text = "", fg = "${theme.hex "blue"}" },
  { name = "rmd", text = "", fg = "${theme.hex "sapphire"}" },
  { name = "vagrantfile$", text = "", fg = "${theme.hex "overlay0"}" },
  { name = ".Xauthority", text = "", fg = "${theme.hex "peach"}" },
  { name = "prettier.config.ts", text = "", fg = "${theme.hex "blue"}" },
  { name = "node_modules", text = "", fg = "${theme.hex "red"}" },
  { name = ".prettierrc.toml", text = "", fg = "${theme.hex "blue"}" },
  { name = "build.zig.zon", text = "", fg = "${theme.hex "peach"}" },
  { name = ".ds_store", text = "", fg = "${theme.hex "surface1"}" },
  { name = "PKGBUILD", text = "", fg = "${theme.hex "blue"}" },
  { name = ".prettierrc", text = "", fg = "${theme.hex "blue"}" },
  { name = ".bash_profile", text = "", fg = "${theme.hex "green"}" },
  { name = ".npmignore", text = "", fg = "${theme.hex "red"}" },
  { name = ".mailmap", text = "󰊢", fg = "${theme.hex "peach"}" },
  { name = ".codespellrc", text = "󰓆", fg = "${theme.hex "green"}" },
  { name = "svelte.config.js", text = "", fg = "${theme.hex "peach"}" },
  { name = "eslint.config.ts", text = "", fg = "${theme.hex "surface1"}" },
  { name = "config", text = "", fg = "${theme.hex "overlay1"}" },
  { name = ".gitlab-ci.yml", text = "", fg = "${theme.hex "red"}" },
  { name = ".gitconfig", text = "", fg = "${theme.hex "peach"}" },
  { name = "_gvimrc", text = "", fg = "${theme.hex "green"}" },
  { name = ".xinitrc", text = "", fg = "${theme.hex "peach"}" },
  { name = "checkhealth", text = "󰓙", fg = "${theme.hex "blue"}" },
  { name = "sxhkdrc", text = "", fg = "${theme.hex "mantle"}" },
  { name = ".bashrc", text = "", fg = "${theme.hex "green"}" },
  { name = "tailwind.config.mjs", text = "󱏿", fg = "${theme.hex "sapphire"}" },
  { name = "ext_typoscript_setup.txt", text = "", fg = "${theme.hex "peach"}" },
  { name = "commitlint.config.ts", text = "󰜘", fg = "${theme.hex "teal"}" },
  { name = "py.typed", text = "", fg = "${theme.hex "yellow"}" },
  { name = ".nanorc", text = "", fg = "${theme.hex "base"}" },
  { name = "commit_editmsg", text = "", fg = "${theme.hex "peach"}" },
  { name = ".luaurc", text = "", fg = "${theme.hex "blue"}" },
  { name = "fp-lib-table", text = "", fg = "${theme.hex "rosewater"}" },
  { name = ".editorconfig", text = "", fg = "${theme.hex "rosewater"}" },
  { name = "justfile", text = "", fg = "${theme.hex "overlay1"}" },
  { name = "kdeglobals", text = "", fg = "${theme.hex "blue"}" },
  { name = "license.md", text = "", fg = "${theme.hex "yellow"}" },
  { name = ".clang-format", text = "", fg = "${theme.hex "overlay1"}" },
  { name = "docker-compose.yaml", text = "󰡨", fg = "${theme.hex "blue"}" },
  { name = "copying", text = "", fg = "${theme.hex "yellow"}" },
  { name = "go.mod", text = "", fg = "${theme.hex "sapphire"}" },
  { name = "lxqt.conf", text = "", fg = "${theme.hex "blue"}" },
  { name = "brewfile", text = "", fg = "${theme.hex "crust"}" },
  { name = "gulpfile.coffee", text = "", fg = "${theme.hex "red"}" },
  { name = ".dockerignore", text = "󰡨", fg = "${theme.hex "blue"}" },
  { name = ".settings.json", text = "", fg = "${theme.hex "surface2"}" },
  { name = "tailwind.config.js", text = "󱏿", fg = "${theme.hex "sapphire"}" },
  { name = ".clang-tidy", text = "", fg = "${theme.hex "overlay1"}" },
  { name = ".gvimrc", text = "", fg = "${theme.hex "green"}" },
  { name = "nuxt.config.cjs", text = "󱄆", fg = "${theme.hex "teal"}" },
  { name = "xsettingsd.conf", text = "", fg = "${theme.hex "peach"}" },
  { name = "nuxt.config.js", text = "󱄆", fg = "${theme.hex "teal"}" },
  { name = "eslint.config.cjs", text = "", fg = "${theme.hex "surface1"}" },
  { name = "sym-lib-table", text = "", fg = "${theme.hex "rosewater"}" },
  { name = ".condarc", text = "", fg = "${theme.hex "green"}" },
  { name = "xmonad.hs", text = "", fg = "${theme.hex "red"}" },
  { name = "tmux.conf", text = "", fg = "${theme.hex "green"}" },
  { name = "xmobarrc.hs", text = "", fg = "${theme.hex "red"}" },
  { name = ".prettierrc.yaml", text = "", fg = "${theme.hex "blue"}" },
  { name = ".pre-commit-config.yaml", text = "󰛢", fg = "${theme.hex "yellow"}" },
  { name = "i3blocks.conf", text = "", fg = "${theme.hex "text"}" },
  { name = "xorg.conf", text = "", fg = "${theme.hex "peach"}" },
  { name = ".zshenv", text = "", fg = "${theme.hex "green"}" },
  { name = "vlcrc", text = "󰕼", fg = "${theme.hex "peach"}" },
  { name = "license", text = "", fg = "${theme.hex "yellow"}" },
  { name = "unlicense", text = "", fg = "${theme.hex "yellow"}" },
  { name = "tmux.conf.local", text = "", fg = "${theme.hex "green"}" },
  { name = ".SRCINFO", text = "󰣇", fg = "${theme.hex "blue"}" },
  { name = "tailwind.config.ts", text = "󱏿", fg = "${theme.hex "sapphire"}" },
  { name = "security.md", text = "󰒃", fg = "${theme.hex "subtext1"}" },
  { name = "security", text = "󰒃", fg = "${theme.hex "subtext1"}" },
  { name = ".eslintrc", text = "", fg = "${theme.hex "surface1"}" },
  { name = "gradle.properties", text = "", fg = "${theme.hex "surface2"}" },
  { name = "code_of_conduct.md", text = "", fg = "${theme.hex "red"}" },
  { name = "PrusaSlicerGcodeViewer.ini", text = "", fg = "${theme.hex "peach"}" },
  { name = "PrusaSlicer.ini", text = "", fg = "${theme.hex "peach"}" },
  { name = "procfile", text = "", fg = "${theme.hex "overlay1"}" },
  { name = "mpv.conf", text = "", fg = "${theme.hex "base"}" },
  { name = ".prettierrc.json5", text = "", fg = "${theme.hex "blue"}" },
  { name = "i3status.conf", text = "", fg = "${theme.hex "text"}" },
  { name = "prettier.config.mjs", text = "", fg = "${theme.hex "blue"}" },
  { name = ".pylintrc", text = "", fg = "${theme.hex "overlay1"}" },
  { name = "prettier.config.cjs", text = "", fg = "${theme.hex "blue"}" },
  { name = ".luacheckrc", text = "", fg = "${theme.hex "blue"}" },
  { name = "containerfile", text = "󰡨", fg = "${theme.hex "blue"}" },
  { name = "eslint.config.mjs", text = "", fg = "${theme.hex "surface1"}" },
  { name = "gruntfile.js", text = "", fg = "${theme.hex "peach"}" },
  { name = "bun.lockb", text = "", fg = "${theme.hex "rosewater"}" },
  { name = ".gitattributes", text = "", fg = "${theme.hex "peach"}" },
  { name = "gruntfile.ts", text = "", fg = "${theme.hex "peach"}" },
  { name = "pom.xml", text = "", fg = "${theme.hex "surface0"}" },
  { name = "favicon.ico", text = "", fg = "${theme.hex "yellow"}" },
  { name = "package-lock.json", text = "", fg = "${theme.hex "surface0"}" },
  { name = "build", text = "", fg = "${theme.hex "green"}" },
  { name = "package.json", text = "", fg = "${theme.hex "red"}" },
  { name = "nuxt.config.ts", text = "󱄆", fg = "${theme.hex "teal"}" },
  { name = "nuxt.config.mjs", text = "󱄆", fg = "${theme.hex "teal"}" },
  { name = "mix.lock", text = "", fg = "${theme.hex "overlay1"}" },
  { name = "makefile", text = "", fg = "${theme.hex "overlay1"}" },
  { name = "gulpfile.js", text = "", fg = "${theme.hex "red"}" },
  { name = "lxde-rc.xml", text = "", fg = "${theme.hex "overlay1"}" },
  { name = "kritarc", text = "", fg = "${theme.hex "mauve"}" },
  { name = "gtkrc", text = "", fg = "${theme.hex "rosewater"}" },
  { name = "ionic.config.json", text = "", fg = "${theme.hex "blue"}" },
  { name = ".prettierrc.mjs", text = "", fg = "${theme.hex "blue"}" },
  { name = ".prettierrc.yml", text = "", fg = "${theme.hex "blue"}" },
  { name = ".npmrc", text = "", fg = "${theme.hex "red"}" },
  { name = "weston.ini", text = "", fg = "${theme.hex "yellow"}" },
  { name = "gulpfile.babel.js", text = "", fg = "${theme.hex "red"}" },
  { name = "i18n.config.ts", text = "󰗊", fg = "${theme.hex "overlay1"}" },
  { name = "commitlint.config.js", text = "󰜘", fg = "${theme.hex "teal"}" },
  { name = ".gitmodules", text = "", fg = "${theme.hex "peach"}" },
  { name = "gradle-wrapper.properties", text = "", fg = "${theme.hex "surface2"}" },
  { name = "hypridle.conf", text = "", fg = "${theme.hex "teal"}" },
  { name = "vercel.json", text = "▲", fg = "${theme.hex "rosewater"}" },
  { name = "hyprlock.conf", text = "", fg = "${theme.hex "teal"}" },
  { name = "go.sum", text = "", fg = "${theme.hex "sapphire"}" },
  { name = "kdenlive-layoutsrc", text = "", fg = "${theme.hex "blue"}" },
  { name = "gruntfile.babel.js", text = "", fg = "${theme.hex "peach"}" },
  { name = "compose.yml", text = "󰡨", fg = "${theme.hex "blue"}" },
  { name = "i18n.config.js", text = "󰗊", fg = "${theme.hex "overlay1"}" },
  { name = "readme.md", text = "󰂺", fg = "${theme.hex "rosewater"}" },
  { name = "gradlew", text = "", fg = "${theme.hex "surface2"}" },
  { name = "go.work", text = "", fg = "${theme.hex "sapphire"}" },
  { name = "gulpfile.ts", text = "", fg = "${theme.hex "red"}" },
  { name = "gnumakefile", text = "", fg = "${theme.hex "overlay1"}" },
  { name = "FreeCAD.conf", text = "", fg = "${theme.hex "red"}" },
  { name = "compose.yaml", text = "󰡨", fg = "${theme.hex "blue"}" },
  { name = "eslint.config.js", text = "", fg = "${theme.hex "surface1"}" },
  { name = "hyprland.conf", text = "", fg = "${theme.hex "teal"}" },
  { name = "docker-compose.yml", text = "󰡨", fg = "${theme.hex "blue"}" },
  { name = "groovy", text = "", fg = "${theme.hex "surface2"}" },
  { name = "QtProject.conf", text = "", fg = "${theme.hex "green"}" },
  { name = "platformio.ini", text = "", fg = "${theme.hex "peach"}" },
  { name = "build.gradle", text = "", fg = "${theme.hex "surface2"}" },
  { name = ".nuxtrc", text = "󱄆", fg = "${theme.hex "teal"}" },
  { name = "_vimrc", text = "", fg = "${theme.hex "green"}" },
  { name = ".zprofile", text = "", fg = "${theme.hex "green"}" },
  { name = ".xsession", text = "", fg = "${theme.hex "peach"}" },
  { name = "prettier.config.js", text = "", fg = "${theme.hex "blue"}" },
  { name = ".babelrc", text = "", fg = "${theme.hex "yellow"}" },
  { name = "workspace", text = "", fg = "${theme.hex "green"}" },
  { name = ".prettierrc.json", text = "", fg = "${theme.hex "blue"}" },
  { name = ".prettierrc.js", text = "", fg = "${theme.hex "blue"}" },
  { name = ".Xresources", text = "", fg = "${theme.hex "peach"}" },
  { name = ".gitignore", text = "", fg = "${theme.hex "peach"}" },
  { name = ".justfile", text = "", fg = "${theme.hex "overlay1"}" },
]
exts = [
  { name = "otf", text = "", fg = "${theme.hex "rosewater"}" },
  { name = "import", text = "", fg = "${theme.hex "rosewater"}" },
  { name = "krz", text = "", fg = "${theme.hex "mauve"}" },
  { name = "adb", text = "", fg = "${theme.hex "teal"}" },
  { name = "ttf", text = "", fg = "${theme.hex "rosewater"}" },
  { name = "webpack", text = "󰜫", fg = "${theme.hex "sapphire"}" },
  { name = "dart", text = "", fg = "${theme.hex "surface2"}" },
  { name = "vsh", text = "", fg = "${theme.hex "overlay1"}" },
  { name = "doc", text = "󰈬", fg = "${theme.hex "surface2"}" },
  { name = "zsh", text = "", fg = "${theme.hex "green"}" },
  { name = "ex", text = "", fg = "${theme.hex "overlay1"}" },
  { name = "hx", text = "", fg = "${theme.hex "peach"}" },
  { name = "fodt", text = "", fg = "${theme.hex "sapphire"}" },
  { name = "mojo", text = "", fg = "${theme.hex "peach"}" },
  { name = "templ", text = "", fg = "${theme.hex "yellow"}" },
  { name = "nix", text = "", fg = "${theme.hex "sapphire"}" },
  { name = "cshtml", text = "󱦗", fg = "${theme.hex "surface1"}" },
  { name = "fish", text = "", fg = "${theme.hex "surface2"}" },
  { name = "ply", text = "󰆧", fg = "${theme.hex "overlay1"}" },
  { name = "sldprt", text = "󰻫", fg = "${theme.hex "green"}" },
  { name = "gemspec", text = "", fg = "${theme.hex "crust"}" },
  { name = "mjs", text = "", fg = "${theme.hex "yellow"}" },
  { name = "csh", text = "", fg = "${theme.hex "surface2"}" },
  { name = "cmake", text = "", fg = "${theme.hex "text"}" },
  { name = "fodp", text = "", fg = "${theme.hex "peach"}" },
  { name = "vi", text = "", fg = "${theme.hex "yellow"}" },
  { name = "msf", text = "", fg = "${theme.hex "blue"}" },
  { name = "blp", text = "󰺾", fg = "${theme.hex "blue"}" },
  { name = "less", text = "", fg = "${theme.hex "surface1"}" },
  { name = "sh", text = "", fg = "${theme.hex "surface2"}" },
  { name = "odg", text = "", fg = "${theme.hex "yellow"}" },
  { name = "mint", text = "󰌪", fg = "${theme.hex "green"}" },
  { name = "dll", text = "", fg = "${theme.hex "crust"}" },
  { name = "odf", text = "", fg = "${theme.hex "red"}" },
  { name = "sqlite3", text = "", fg = "${theme.hex "rosewater"}" },
  { name = "Dockerfile", text = "󰡨", fg = "${theme.hex "blue"}" },
  { name = "ksh", text = "", fg = "${theme.hex "surface2"}" },
  { name = "rmd", text = "", fg = "${theme.hex "sapphire"}" },
  { name = "wv", text = "", fg = "${theme.hex "sapphire"}" },
  { name = "xml", text = "󰗀", fg = "${theme.hex "peach"}" },
  { name = "markdown", text = "", fg = "${theme.hex "text"}" },
  { name = "qml", text = "", fg = "${theme.hex "green"}" },
  { name = "3gp", text = "", fg = "${theme.hex "peach"}" },
  { name = "pxi", text = "", fg = "${theme.hex "blue"}" },
  { name = "flac", text = "", fg = "${theme.hex "overlay0"}" },
  { name = "gpr", text = "", fg = "${theme.hex "mauve"}" },
  { name = "huff", text = "󰡘", fg = "${theme.hex "surface1"}" },
  { name = "json", text = "", fg = "${theme.hex "yellow"}" },
  { name = "gv", text = "󱁉", fg = "${theme.hex "surface2"}" },
  { name = "bmp", text = "", fg = "${theme.hex "overlay1"}" },
  { name = "lock", text = "", fg = "${theme.hex "subtext1"}" },
  { name = "sha384", text = "󰕥", fg = "${theme.hex "overlay1"}" },
  { name = "cobol", text = "⚙", fg = "${theme.hex "surface2"}" },
  { name = "cob", text = "⚙", fg = "${theme.hex "surface2"}" },
  { name = "java", text = "", fg = "${theme.hex "red"}" },
  { name = "cjs", text = "", fg = "${theme.hex "yellow"}" },
  { name = "qm", text = "", fg = "${theme.hex "sapphire"}" },
  { name = "ebuild", text = "", fg = "${theme.hex "surface1"}" },
  { name = "mustache", text = "", fg = "${theme.hex "peach"}" },
  { name = "terminal", text = "", fg = "${theme.hex "green"}" },
  { name = "ejs", text = "", fg = "${theme.hex "yellow"}" },
  { name = "brep", text = "󰻫", fg = "${theme.hex "green"}" },
  { name = "rar", text = "", fg = "${theme.hex "yellow"}" },
  { name = "gradle", text = "", fg = "${theme.hex "surface2"}" },
  { name = "gnumakefile", text = "", fg = "${theme.hex "overlay1"}" },
  { name = "applescript", text = "", fg = "${theme.hex "overlay1"}" },
  { name = "elm", text = "", fg = "${theme.hex "sapphire"}" },
  { name = "ebook", text = "", fg = "${theme.hex "peach"}" },
  { name = "kra", text = "", fg = "${theme.hex "mauve"}" },
  { name = "tf", text = "", fg = "${theme.hex "surface2"}" },
  { name = "xls", text = "󰈛", fg = "${theme.hex "surface2"}" },
  { name = "fnl", text = "", fg = "${theme.hex "yellow"}" },
  { name = "kdbx", text = "", fg = "${theme.hex "green"}" },
  { name = "kicad_pcb", text = "", fg = "${theme.hex "rosewater"}" },
  { name = "cfg", text = "", fg = "${theme.hex "overlay1"}" },
  { name = "ape", text = "", fg = "${theme.hex "sapphire"}" },
  { name = "org", text = "", fg = "${theme.hex "teal"}" },
  { name = "yml", text = "", fg = "${theme.hex "overlay1"}" },
  { name = "swift", text = "", fg = "${theme.hex "peach"}" },
  { name = "eln", text = "", fg = "${theme.hex "overlay0"}" },
  { name = "sol", text = "", fg = "${theme.hex "sapphire"}" },
  { name = "awk", text = "", fg = "${theme.hex "surface2"}" },
  { name = "7z", text = "", fg = "${theme.hex "yellow"}" },
  { name = "apl", text = "⍝", fg = "${theme.hex "peach"}" },
  { name = "epp", text = "", fg = "${theme.hex "peach"}" },
  { name = "app", text = "", fg = "${theme.hex "surface1"}" },
  { name = "dot", text = "󱁉", fg = "${theme.hex "surface2"}" },
  { name = "kpp", text = "", fg = "${theme.hex "mauve"}" },
  { name = "eot", text = "", fg = "${theme.hex "rosewater"}" },
  { name = "hpp", text = "", fg = "${theme.hex "overlay1"}" },
  { name = "spec.tsx", text = "", fg = "${theme.hex "surface2"}" },
  { name = "hurl", text = "", fg = "${theme.hex "red"}" },
  { name = "cxxm", text = "", fg = "${theme.hex "sapphire"}" },
  { name = "c", text = "", fg = "${theme.hex "blue"}" },
  { name = "fcmacro", text = "", fg = "${theme.hex "red"}" },
  { name = "sass", text = "", fg = "${theme.hex "red"}" },
  { name = "yaml", text = "", fg = "${theme.hex "overlay1"}" },
  { name = "xz", text = "", fg = "${theme.hex "yellow"}" },
  { name = "material", text = "󰔉", fg = "${theme.hex "overlay0"}" },
  { name = "json5", text = "", fg = "${theme.hex "yellow"}" },
  { name = "signature", text = "λ", fg = "${theme.hex "peach"}" },
  { name = "3mf", text = "󰆧", fg = "${theme.hex "overlay1"}" },
  { name = "jpg", text = "", fg = "${theme.hex "overlay1"}" },
  { name = "xpi", text = "", fg = "${theme.hex "peach"}" },
  { name = "fcmat", text = "", fg = "${theme.hex "red"}" },
  { name = "pot", text = "", fg = "${theme.hex "sapphire"}" },
  { name = "bin", text = "", fg = "${theme.hex "surface1"}" },
  { name = "xlsx", text = "󰈛", fg = "${theme.hex "surface2"}" },
  { name = "aac", text = "", fg = "${theme.hex "sapphire"}" },
  { name = "kicad_sym", text = "", fg = "${theme.hex "rosewater"}" },
  { name = "xcstrings", text = "", fg = "${theme.hex "sapphire"}" },
  { name = "lff", text = "", fg = "${theme.hex "rosewater"}" },
  { name = "xcf", text = "", fg = "${theme.hex "surface2"}" },
  { name = "azcli", text = "", fg = "${theme.hex "overlay0"}" },
  { name = "license", text = "", fg = "${theme.hex "yellow"}" },
  { name = "jsonc", text = "", fg = "${theme.hex "yellow"}" },
  { name = "xaml", text = "󰙳", fg = "${theme.hex "surface1"}" },
  { name = "md5", text = "󰕥", fg = "${theme.hex "overlay1"}" },
  { name = "xm", text = "", fg = "${theme.hex "sapphire"}" },
  { name = "sln", text = "", fg = "${theme.hex "surface2"}" },
  { name = "jl", text = "", fg = "${theme.hex "overlay1"}" },
  { name = "ml", text = "", fg = "${theme.hex "peach"}" },
  { name = "http", text = "", fg = "${theme.hex "blue"}" },
  { name = "x", text = "", fg = "${theme.hex "blue"}" },
  { name = "wvc", text = "", fg = "${theme.hex "sapphire"}" },
  { name = "wrz", text = "󰆧", fg = "${theme.hex "overlay1"}" },
  { name = "csproj", text = "󰪮", fg = "${theme.hex "surface1"}" },
  { name = "wrl", text = "󰆧", fg = "${theme.hex "overlay1"}" },
  { name = "wma", text = "", fg = "${theme.hex "sapphire"}" },
  { name = "woff2", text = "", fg = "${theme.hex "rosewater"}" },
  { name = "woff", text = "", fg = "${theme.hex "rosewater"}" },
  { name = "tscn", text = "", fg = "${theme.hex "overlay1"}" },
  { name = "webmanifest", text = "", fg = "${theme.hex "yellow"}" },
  { name = "webm", text = "", fg = "${theme.hex "peach"}" },
  { name = "fcbak", text = "", fg = "${theme.hex "red"}" },
  { name = "log", text = "󰌱", fg = "${theme.hex "text"}" },
  { name = "wav", text = "", fg = "${theme.hex "sapphire"}" },
  { name = "wasm", text = "", fg = "${theme.hex "surface2"}" },
  { name = "styl", text = "", fg = "${theme.hex "green"}" },
  { name = "gif", text = "", fg = "${theme.hex "overlay1"}" },
  { name = "resi", text = "", fg = "${theme.hex "red"}" },
  { name = "aiff", text = "", fg = "${theme.hex "sapphire"}" },
  { name = "sha256", text = "󰕥", fg = "${theme.hex "overlay1"}" },
  { name = "igs", text = "󰻫", fg = "${theme.hex "green"}" },
  { name = "vsix", text = "", fg = "${theme.hex "surface2"}" },
  { name = "vim", text = "", fg = "${theme.hex "green"}" },
  { name = "diff", text = "", fg = "${theme.hex "surface1"}" },
  { name = "drl", text = "", fg = "${theme.hex "maroon"}" },
  { name = "erl", text = "", fg = "${theme.hex "overlay0"}" },
  { name = "vhdl", text = "󰍛", fg = "${theme.hex "green"}" },
  { name = "🔥", text = "", fg = "${theme.hex "peach"}" },
  { name = "hrl", text = "", fg = "${theme.hex "overlay0"}" },
  { name = "fsi", text = "", fg = "${theme.hex "sapphire"}" },
  { name = "mm", text = "", fg = "${theme.hex "sapphire"}" },
  { name = "bz", text = "", fg = "${theme.hex "yellow"}" },
  { name = "vh", text = "󰍛", fg = "${theme.hex "green"}" },
  { name = "kdb", text = "", fg = "${theme.hex "green"}" },
  { name = "gz", text = "", fg = "${theme.hex "yellow"}" },
  { name = "cpp", text = "", fg = "${theme.hex "sapphire"}" },
  { name = "ui", text = "", fg = "${theme.hex "surface2"}" },
  { name = "txt", text = "󰈙", fg = "${theme.hex "green"}" },
  { name = "spec.ts", text = "", fg = "${theme.hex "sapphire"}" },
  { name = "ccm", text = "", fg = "${theme.hex "red"}" },
  { name = "typoscript", text = "", fg = "${theme.hex "peach"}" },
  { name = "typ", text = "", fg = "${theme.hex "teal"}" },
  { name = "txz", text = "", fg = "${theme.hex "yellow"}" },
  { name = "test.ts", text = "", fg = "${theme.hex "sapphire"}" },
  { name = "tsx", text = "", fg = "${theme.hex "surface2"}" },
  { name = "mk", text = "", fg = "${theme.hex "overlay1"}" },
  { name = "webp", text = "", fg = "${theme.hex "overlay1"}" },
  { name = "opus", text = "", fg = "${theme.hex "overlay0"}" },
  { name = "bicep", text = "", fg = "${theme.hex "sapphire"}" },
  { name = "ts", text = "", fg = "${theme.hex "sapphire"}" },
  { name = "tres", text = "", fg = "${theme.hex "overlay1"}" },
  { name = "torrent", text = "", fg = "${theme.hex "teal"}" },
  { name = "cxx", text = "", fg = "${theme.hex "sapphire"}" },
  { name = "iso", text = "", fg = "${theme.hex "flamingo"}" },
  { name = "ixx", text = "", fg = "${theme.hex "sapphire"}" },
  { name = "hxx", text = "", fg = "${theme.hex "overlay1"}" },
  { name = "gql", text = "", fg = "${theme.hex "red"}" },
  { name = "tmux", text = "", fg = "${theme.hex "green"}" },
  { name = "ini", text = "", fg = "${theme.hex "overlay1"}" },
  { name = "m3u8", text = "󰲹", fg = "${theme.hex "red"}" },
  { name = "image", text = "", fg = "${theme.hex "flamingo"}" },
  { name = "tfvars", text = "", fg = "${theme.hex "surface2"}" },
  { name = "tex", text = "", fg = "${theme.hex "surface1"}" },
  { name = "cbl", text = "⚙", fg = "${theme.hex "surface2"}" },
  { name = "flc", text = "", fg = "${theme.hex "rosewater"}" },
  { name = "elc", text = "", fg = "${theme.hex "overlay0"}" },
  { name = "test.tsx", text = "", fg = "${theme.hex "surface2"}" },
  { name = "twig", text = "", fg = "${theme.hex "green"}" },
  { name = "sql", text = "", fg = "${theme.hex "rosewater"}" },
  { name = "test.jsx", text = "", fg = "${theme.hex "sapphire"}" },
  { name = "htm", text = "", fg = "${theme.hex "peach"}" },
  { name = "gcode", text = "󰐫", fg = "${theme.hex "overlay0"}" },
  { name = "test.js", text = "", fg = "${theme.hex "yellow"}" },
  { name = "ino", text = "", fg = "${theme.hex "sapphire"}" },
  { name = "tcl", text = "󰛓", fg = "${theme.hex "surface2"}" },
  { name = "cljs", text = "", fg = "${theme.hex "sapphire"}" },
  { name = "tsconfig", text = "", fg = "${theme.hex "peach"}" },
  { name = "img", text = "", fg = "${theme.hex "flamingo"}" },
  { name = "t", text = "", fg = "${theme.hex "sapphire"}" },
  { name = "fcstd1", text = "", fg = "${theme.hex "red"}" },
  { name = "out", text = "", fg = "${theme.hex "surface1"}" },
  { name = "jsx", text = "", fg = "${theme.hex "sapphire"}" },
  { name = "bash", text = "", fg = "${theme.hex "green"}" },
  { name = "edn", text = "", fg = "${theme.hex "sapphire"}" },
  { name = "rss", text = "", fg = "${theme.hex "peach"}" },
  { name = "flf", text = "", fg = "${theme.hex "rosewater"}" },
  { name = "cache", text = "", fg = "${theme.hex "rosewater"}" },
  { name = "sbt", text = "", fg = "${theme.hex "red"}" },
  { name = "cppm", text = "", fg = "${theme.hex "sapphire"}" },
  { name = "svelte", text = "", fg = "${theme.hex "peach"}" },
  { name = "mo", text = "∞", fg = "${theme.hex "overlay1"}" },
  { name = "sv", text = "󰍛", fg = "${theme.hex "green"}" },
  { name = "ko", text = "", fg = "${theme.hex "rosewater"}" },
  { name = "suo", text = "", fg = "${theme.hex "surface2"}" },
  { name = "sldasm", text = "󰻫", fg = "${theme.hex "green"}" },
  { name = "icalendar", text = "", fg = "${theme.hex "surface0"}" },
  { name = "go", text = "", fg = "${theme.hex "sapphire"}" },
  { name = "sublime", text = "", fg = "${theme.hex "peach"}" },
  { name = "stl", text = "󰆧", fg = "${theme.hex "overlay1"}" },
  { name = "mobi", text = "", fg = "${theme.hex "peach"}" },
  { name = "graphql", text = "", fg = "${theme.hex "red"}" },
  { name = "m3u", text = "󰲹", fg = "${theme.hex "red"}" },
  { name = "cpy", text = "⚙", fg = "${theme.hex "surface2"}" },
  { name = "kdenlive", text = "", fg = "${theme.hex "blue"}" },
  { name = "pyo", text = "", fg = "${theme.hex "yellow"}" },
  { name = "po", text = "", fg = "${theme.hex "sapphire"}" },
  { name = "scala", text = "", fg = "${theme.hex "red"}" },
  { name = "exs", text = "", fg = "${theme.hex "overlay1"}" },
  { name = "odp", text = "", fg = "${theme.hex "peach"}" },
  { name = "dump", text = "", fg = "${theme.hex "rosewater"}" },
  { name = "stp", text = "󰻫", fg = "${theme.hex "green"}" },
  { name = "step", text = "󰻫", fg = "${theme.hex "green"}" },
  { name = "ste", text = "󰻫", fg = "${theme.hex "green"}" },
  { name = "aif", text = "", fg = "${theme.hex "sapphire"}" },
  { name = "strings", text = "", fg = "${theme.hex "sapphire"}" },
  { name = "cp", text = "", fg = "${theme.hex "sapphire"}" },
  { name = "fsscript", text = "", fg = "${theme.hex "sapphire"}" },
  { name = "mli", text = "", fg = "${theme.hex "peach"}" },
  { name = "bak", text = "󰁯", fg = "${theme.hex "overlay1"}" },
  { name = "ssa", text = "󰨖", fg = "${theme.hex "yellow"}" },
  { name = "toml", text = "", fg = "${theme.hex "red"}" },
  { name = "makefile", text = "", fg = "${theme.hex "overlay1"}" },
  { name = "php", text = "", fg = "${theme.hex "overlay1"}" },
  { name = "zst", text = "", fg = "${theme.hex "yellow"}" },
  { name = "spec.jsx", text = "", fg = "${theme.hex "sapphire"}" },
  { name = "kbx", text = "󰯄", fg = "${theme.hex "overlay0"}" },
  { name = "fbx", text = "󰆧", fg = "${theme.hex "overlay1"}" },
  { name = "blend", text = "󰂫", fg = "${theme.hex "peach"}" },
  { name = "ifc", text = "󰻫", fg = "${theme.hex "green"}" },
  { name = "spec.js", text = "", fg = "${theme.hex "yellow"}" },
  { name = "so", text = "", fg = "${theme.hex "rosewater"}" },
  { name = "desktop", text = "", fg = "${theme.hex "surface1"}" },
  { name = "sml", text = "λ", fg = "${theme.hex "peach"}" },
  { name = "slvs", text = "󰻫", fg = "${theme.hex "green"}" },
  { name = "pp", text = "", fg = "${theme.hex "peach"}" },
  { name = "ps1", text = "󰨊", fg = "${theme.hex "overlay0"}" },
  { name = "dropbox", text = "", fg = "${theme.hex "overlay0"}" },
  { name = "kicad_mod", text = "", fg = "${theme.hex "rosewater"}" },
  { name = "bat", text = "", fg = "${theme.hex "green"}" },
  { name = "slim", text = "", fg = "${theme.hex "peach"}" },
  { name = "skp", text = "󰻫", fg = "${theme.hex "green"}" },
  { name = "css", text = "", fg = "${theme.hex "blue"}" },
  { name = "xul", text = "", fg = "${theme.hex "peach"}" },
  { name = "ige", text = "󰻫", fg = "${theme.hex "green"}" },
  { name = "glb", text = "", fg = "${theme.hex "peach"}" },
  { name = "ppt", text = "󰈧", fg = "${theme.hex "red"}" },
  { name = "sha512", text = "󰕥", fg = "${theme.hex "overlay1"}" },
  { name = "ics", text = "", fg = "${theme.hex "surface0"}" },
  { name = "mdx", text = "", fg = "${theme.hex "sapphire"}" },
  { name = "sha1", text = "󰕥", fg = "${theme.hex "overlay1"}" },
  { name = "f3d", text = "󰻫", fg = "${theme.hex "green"}" },
  { name = "ass", text = "󰨖", fg = "${theme.hex "yellow"}" },
  { name = "godot", text = "", fg = "${theme.hex "overlay1"}" },
  { name = "ifb", text = "", fg = "${theme.hex "surface0"}" },
  { name = "cson", text = "", fg = "${theme.hex "yellow"}" },
  { name = "lib", text = "", fg = "${theme.hex "crust"}" },
  { name = "luac", text = "", fg = "${theme.hex "sapphire"}" },
  { name = "heex", text = "", fg = "${theme.hex "overlay1"}" },
  { name = "scm", text = "󰘧", fg = "${theme.hex "rosewater"}" },
  { name = "psd1", text = "󰨊", fg = "${theme.hex "overlay0"}" },
  { name = "sc", text = "", fg = "${theme.hex "red"}" },
  { name = "scad", text = "", fg = "${theme.hex "yellow"}" },
  { name = "kts", text = "", fg = "${theme.hex "overlay0"}" },
  { name = "svh", text = "󰍛", fg = "${theme.hex "green"}" },
  { name = "mts", text = "", fg = "${theme.hex "sapphire"}" },
  { name = "nfo", text = "", fg = "${theme.hex "yellow"}" },
  { name = "pck", text = "", fg = "${theme.hex "overlay1"}" },
  { name = "rproj", text = "󰗆", fg = "${theme.hex "green"}" },
  { name = "rlib", text = "", fg = "${theme.hex "peach"}" },
  { name = "cljd", text = "", fg = "${theme.hex "sapphire"}" },
  { name = "ods", text = "", fg = "${theme.hex "green"}" },
  { name = "res", text = "", fg = "${theme.hex "red"}" },
  { name = "apk", text = "", fg = "${theme.hex "green"}" },
  { name = "haml", text = "", fg = "${theme.hex "rosewater"}" },
  { name = "d.ts", text = "", fg = "${theme.hex "peach"}" },
  { name = "razor", text = "󱦘", fg = "${theme.hex "surface1"}" },
  { name = "rake", text = "", fg = "${theme.hex "crust"}" },
  { name = "patch", text = "", fg = "${theme.hex "surface1"}" },
  { name = "cuh", text = "", fg = "${theme.hex "overlay1"}" },
  { name = "d", text = "", fg = "${theme.hex "red"}" },
  { name = "query", text = "", fg = "${theme.hex "green"}" },
  { name = "psb", text = "", fg = "${theme.hex "sapphire"}" },
  { name = "nu", text = ">", fg = "${theme.hex "green"}" },
  { name = "mov", text = "", fg = "${theme.hex "peach"}" },
  { name = "lrc", text = "󰨖", fg = "${theme.hex "yellow"}" },
  { name = "pyx", text = "", fg = "${theme.hex "blue"}" },
  { name = "pyw", text = "", fg = "${theme.hex "blue"}" },
  { name = "cu", text = "", fg = "${theme.hex "green"}" },
  { name = "bazel", text = "", fg = "${theme.hex "green"}" },
  { name = "obj", text = "󰆧", fg = "${theme.hex "overlay1"}" },
  { name = "pyi", text = "", fg = "${theme.hex "yellow"}" },
  { name = "pyd", text = "", fg = "${theme.hex "yellow"}" },
  { name = "exe", text = "", fg = "${theme.hex "surface1"}" },
  { name = "pyc", text = "", fg = "${theme.hex "yellow"}" },
  { name = "fctb", text = "", fg = "${theme.hex "red"}" },
  { name = "part", text = "", fg = "${theme.hex "teal"}" },
  { name = "blade.php", text = "", fg = "${theme.hex "red"}" },
  { name = "git", text = "", fg = "${theme.hex "peach"}" },
  { name = "psd", text = "", fg = "${theme.hex "sapphire"}" },
  { name = "qss", text = "", fg = "${theme.hex "green"}" },
  { name = "csv", text = "", fg = "${theme.hex "green"}" },
  { name = "psm1", text = "󰨊", fg = "${theme.hex "overlay0"}" },
  { name = "dconf", text = "", fg = "${theme.hex "rosewater"}" },
  { name = "config.ru", text = "", fg = "${theme.hex "crust"}" },
  { name = "prisma", text = "", fg = "${theme.hex "overlay0"}" },
  { name = "conf", text = "", fg = "${theme.hex "overlay1"}" },
  { name = "clj", text = "", fg = "${theme.hex "green"}" },
  { name = "o", text = "", fg = "${theme.hex "surface1"}" },
  { name = "mp4", text = "", fg = "${theme.hex "peach"}" },
  { name = "cc", text = "", fg = "${theme.hex "red"}" },
  { name = "kicad_prl", text = "", fg = "${theme.hex "rosewater"}" },
  { name = "bz3", text = "", fg = "${theme.hex "yellow"}" },
  { name = "asc", text = "󰦝", fg = "${theme.hex "surface2"}" },
  { name = "png", text = "", fg = "${theme.hex "overlay1"}" },
  { name = "android", text = "", fg = "${theme.hex "green"}" },
  { name = "pm", text = "", fg = "${theme.hex "sapphire"}" },
  { name = "h", text = "", fg = "${theme.hex "overlay1"}" },
  { name = "pls", text = "󰲹", fg = "${theme.hex "red"}" },
  { name = "ipynb", text = "", fg = "${theme.hex "peach"}" },
  { name = "pl", text = "", fg = "${theme.hex "sapphire"}" },
  { name = "ads", text = "", fg = "${theme.hex "rosewater"}" },
  { name = "sqlite", text = "", fg = "${theme.hex "rosewater"}" },
  { name = "pdf", text = "", fg = "${theme.hex "red"}" },
  { name = "pcm", text = "", fg = "${theme.hex "overlay0"}" },
  { name = "ico", text = "", fg = "${theme.hex "yellow"}" },
  { name = "a", text = "", fg = "${theme.hex "rosewater"}" },
  { name = "R", text = "󰟔", fg = "${theme.hex "surface2"}" },
  { name = "ogg", text = "", fg = "${theme.hex "overlay0"}" },
  { name = "pxd", text = "", fg = "${theme.hex "blue"}" },
  { name = "kdenlivetitle", text = "", fg = "${theme.hex "blue"}" },
  { name = "jxl", text = "", fg = "${theme.hex "overlay1"}" },
  { name = "nswag", text = "", fg = "${theme.hex "green"}" },
  { name = "nim", text = "", fg = "${theme.hex "yellow"}" },
  { name = "bqn", text = "⎉", fg = "${theme.hex "surface2"}" },
  { name = "cts", text = "", fg = "${theme.hex "sapphire"}" },
  { name = "fcparam", text = "", fg = "${theme.hex "red"}" },
  { name = "rs", text = "", fg = "${theme.hex "peach"}" },
  { name = "mpp", text = "", fg = "${theme.hex "sapphire"}" },
  { name = "fdmdownload", text = "", fg = "${theme.hex "teal"}" },
  { name = "pptx", text = "󰈧", fg = "${theme.hex "red"}" },
  { name = "jpeg", text = "", fg = "${theme.hex "overlay1"}" },
  { name = "bib", text = "󱉟", fg = "${theme.hex "yellow"}" },
  { name = "vhd", text = "󰍛", fg = "${theme.hex "green"}" },
  { name = "m", text = "", fg = "${theme.hex "blue"}" },
  { name = "js", text = "", fg = "${theme.hex "yellow"}" },
  { name = "eex", text = "", fg = "${theme.hex "overlay1"}" },
  { name = "tbc", text = "󰛓", fg = "${theme.hex "surface2"}" },
  { name = "astro", text = "", fg = "${theme.hex "red"}" },
  { name = "sha224", text = "󰕥", fg = "${theme.hex "overlay1"}" },
  { name = "xcplayground", text = "", fg = "${theme.hex "peach"}" },
  { name = "el", text = "", fg = "${theme.hex "overlay0"}" },
  { name = "m4v", text = "", fg = "${theme.hex "peach"}" },
  { name = "m4a", text = "", fg = "${theme.hex "sapphire"}" },
  { name = "cs", text = "󰌛", fg = "${theme.hex "green"}" },
  { name = "hs", text = "", fg = "${theme.hex "overlay1"}" },
  { name = "tgz", text = "", fg = "${theme.hex "yellow"}" },
  { name = "fs", text = "", fg = "${theme.hex "sapphire"}" },
  { name = "luau", text = "", fg = "${theme.hex "blue"}" },
  { name = "dxf", text = "󰻫", fg = "${theme.hex "green"}" },
  { name = "download", text = "", fg = "${theme.hex "teal"}" },
  { name = "cast", text = "", fg = "${theme.hex "peach"}" },
  { name = "qrc", text = "", fg = "${theme.hex "green"}" },
  { name = "lua", text = "", fg = "${theme.hex "sapphire"}" },
  { name = "lhs", text = "", fg = "${theme.hex "overlay1"}" },
  { name = "md", text = "", fg = "${theme.hex "text"}" },
  { name = "leex", text = "", fg = "${theme.hex "overlay1"}" },
  { name = "ai", text = "", fg = "${theme.hex "yellow"}" },
  { name = "lck", text = "", fg = "${theme.hex "subtext1"}" },
  { name = "kt", text = "", fg = "${theme.hex "overlay0"}" },
  { name = "bicepparam", text = "", fg = "${theme.hex "overlay1"}" },
  { name = "hex", text = "", fg = "${theme.hex "overlay0"}" },
  { name = "zig", text = "", fg = "${theme.hex "peach"}" },
  { name = "bzl", text = "", fg = "${theme.hex "green"}" },
  { name = "cljc", text = "", fg = "${theme.hex "green"}" },
  { name = "kicad_dru", text = "", fg = "${theme.hex "rosewater"}" },
  { name = "fctl", text = "", fg = "${theme.hex "red"}" },
  { name = "f#", text = "", fg = "${theme.hex "sapphire"}" },
  { name = "odt", text = "", fg = "${theme.hex "sapphire"}" },
  { name = "conda", text = "", fg = "${theme.hex "green"}" },
  { name = "vala", text = "", fg = "${theme.hex "surface2"}" },
  { name = "erb", text = "", fg = "${theme.hex "crust"}" },
  { name = "mp3", text = "", fg = "${theme.hex "sapphire"}" },
  { name = "bz2", text = "", fg = "${theme.hex "yellow"}" },
  { name = "coffee", text = "", fg = "${theme.hex "yellow"}" },
  { name = "cr", text = "", fg = "${theme.hex "rosewater"}" },
  { name = "f90", text = "󱈚", fg = "${theme.hex "surface2"}" },
  { name = "jwmrc", text = "", fg = "${theme.hex "overlay0"}" },
  { name = "c++", text = "", fg = "${theme.hex "red"}" },
  { name = "fcscript", text = "", fg = "${theme.hex "red"}" },
  { name = "fods", text = "", fg = "${theme.hex "green"}" },
  { name = "cue", text = "󰲹", fg = "${theme.hex "red"}" },
  { name = "srt", text = "󰨖", fg = "${theme.hex "yellow"}" },
  { name = "info", text = "", fg = "${theme.hex "yellow"}" },
  { name = "hh", text = "", fg = "${theme.hex "overlay1"}" },
  { name = "sig", text = "λ", fg = "${theme.hex "peach"}" },
  { name = "html", text = "", fg = "${theme.hex "peach"}" },
  { name = "iges", text = "󰻫", fg = "${theme.hex "green"}" },
  { name = "kicad_wks", text = "", fg = "${theme.hex "rosewater"}" },
  { name = "hbs", text = "", fg = "${theme.hex "peach"}" },
  { name = "fcstd", text = "", fg = "${theme.hex "red"}" },
  { name = "gresource", text = "", fg = "${theme.hex "rosewater"}" },
  { name = "sub", text = "󰨖", fg = "${theme.hex "yellow"}" },
  { name = "ical", text = "", fg = "${theme.hex "surface0"}" },
  { name = "crdownload", text = "", fg = "${theme.hex "teal"}" },
  { name = "pub", text = "󰷖", fg = "${theme.hex "yellow"}" },
  { name = "vue", text = "", fg = "${theme.hex "green"}" },
  { name = "gd", text = "", fg = "${theme.hex "overlay1"}" },
  { name = "fsx", text = "", fg = "${theme.hex "sapphire"}" },
  { name = "mkv", text = "", fg = "${theme.hex "peach"}" },
  { name = "py", text = "", fg = "${theme.hex "yellow"}" },
  { name = "kicad_sch", text = "", fg = "${theme.hex "rosewater"}" },
  { name = "epub", text = "", fg = "${theme.hex "peach"}" },
  { name = "env", text = "", fg = "${theme.hex "yellow"}" },
  { name = "magnet", text = "", fg = "${theme.hex "surface1"}" },
  { name = "elf", text = "", fg = "${theme.hex "surface1"}" },
  { name = "fodg", text = "", fg = "${theme.hex "yellow"}" },
  { name = "svg", text = "󰜡", fg = "${theme.hex "peach"}" },
  { name = "dwg", text = "󰻫", fg = "${theme.hex "green"}" },
  { name = "docx", text = "󰈬", fg = "${theme.hex "surface2"}" },
  { name = "pro", text = "", fg = "${theme.hex "yellow"}" },
  { name = "db", text = "", fg = "${theme.hex "rosewater"}" },
  { name = "rb", text = "", fg = "${theme.hex "crust"}" },
  { name = "r", text = "󰟔", fg = "${theme.hex "surface2"}" },
  { name = "scss", text = "", fg = "${theme.hex "red"}" },
  { name = "cow", text = "󰆚", fg = "${theme.hex "peach"}" },
  { name = "gleam", text = "", fg = "${theme.hex "pink"}" },
  { name = "v", text = "󰍛", fg = "${theme.hex "green"}" },
  { name = "kicad_pro", text = "", fg = "${theme.hex "rosewater"}" },
  { name = "liquid", text = "", fg = "${theme.hex "green"}" },
  { name = "zip", text = "", fg = "${theme.hex "yellow"}" },
]
  '';

  yaziSyntectTheme = ''
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
      <dict>
        <key>name</key>
        <string>${theme.familyTitle} ${theme.flavorTitle}</string>
        <key>settings</key>
        <array>
          <dict>
            <key>settings</key>
            <dict>
              <key>background</key>
              <string>${theme.hex "base"}</string>
              <key>foreground</key>
              <string>${theme.hex "text"}</string>
              <key>caret</key>
              <string>${theme.hex "rosewater"}</string>
              <key>selection</key>
              <string>${theme.hex "surface0"}</string>
              <key>invisibles</key>
              <string>${theme.hex "overlay0"}</string>
              <key>lineHighlight</key>
              <string>${theme.hex "mantle"}</string>
            </dict>
          </dict>
          <dict>
            <key>name</key>
            <string>Comment</string>
            <key>scope</key>
            <string>comment</string>
            <key>settings</key>
            <dict>
              <key>foreground</key>
              <string>${theme.hex "overlay1"}</string>
              <key>fontStyle</key>
              <string>italic</string>
            </dict>
          </dict>
          <dict>
            <key>name</key>
            <string>String</string>
            <key>scope</key>
            <string>string</string>
            <key>settings</key>
            <dict>
              <key>foreground</key>
              <string>${theme.hex "green"}</string>
            </dict>
          </dict>
          <dict>
            <key>name</key>
            <string>Keyword</string>
            <key>scope</key>
            <string>keyword, storage</string>
            <key>settings</key>
            <dict>
              <key>foreground</key>
              <string>${theme.hex "mauve"}</string>
            </dict>
          </dict>
          <dict>
            <key>name</key>
            <string>Function</string>
            <key>scope</key>
            <string>entity.name.function, support.function</string>
            <key>settings</key>
            <dict>
              <key>foreground</key>
              <string>${theme.hex "blue"}</string>
            </dict>
          </dict>
          <dict>
            <key>name</key>
            <string>Type</string>
            <key>scope</key>
            <string>entity.name.type, support.type, support.class</string>
            <key>settings</key>
            <dict>
              <key>foreground</key>
              <string>${theme.hex "yellow"}</string>
            </dict>
          </dict>
          <dict>
            <key>name</key>
            <string>Constant</string>
            <key>scope</key>
            <string>constant, constant.numeric</string>
            <key>settings</key>
            <dict>
              <key>foreground</key>
              <string>${theme.hex "peach"}</string>
            </dict>
          </dict>
          <dict>
            <key>name</key>
            <string>Variable</string>
            <key>scope</key>
            <string>variable, variable.parameter</string>
            <key>settings</key>
            <dict>
              <key>foreground</key>
              <string>${theme.hex "text"}</string>
            </dict>
          </dict>
          <dict>
            <key>name</key>
            <string>Punctuation</string>
            <key>scope</key>
            <string>punctuation</string>
            <key>settings</key>
            <dict>
              <key>foreground</key>
              <string>${theme.hex "overlay2"}</string>
            </dict>
          </dict>
          <dict>
            <key>name</key>
            <string>Invalid</string>
            <key>scope</key>
            <string>invalid</string>
            <key>settings</key>
            <dict>
              <key>foreground</key>
              <string>${theme.hex "red"}</string>
            </dict>
          </dict>
        </array>
      </dict>
    </plist>
  '';
}
