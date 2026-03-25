{ lib, pkgs, config, theme, ... }:
with lib;
let
  program = "nushell";
  program-module = config.modules.${program};
  homeDir = config.home.homeDirectory;
  neovimProvider = theme.lookupProvider "neovim";
  nushellProvider = theme.lookupProvider "nushell";
  fzfProvider = theme.lookupProvider "fzf";
  neovimColorscheme =
    theme.lookupProviderOption neovimProvider "colorscheme";
  themeNuPath = "${homeDir}/.config/dotfiles-theme/nushell.nu";
  fzfThemeNuPath = "${homeDir}/.config/dotfiles-theme/fzf.nu";

  renderNushellTheme = colors: ''
    let theme = {
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: value: "  ${name}: \"${value}\"") colors)}
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
      datetime: {|| (date now) - $in |
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
      status_bar_background: { fg: $theme.text, bg: $theme.mantle },
      command_bar_text: { fg: $theme.text },
      highlight: { fg: $theme.base, bg: $theme.yellow },
      status: {
        error: $theme.red,
        warn: $theme.yellow,
        info: $theme.blue,
      },
      selected_cell: { bg: $theme.blue fg: $theme.base },
    }
  '';

  # Nushell accepts either generated inline color config from a structured
  # provider or one upstream asset file copied into the handoff path.
  nushellTheme = theme.matchProvider nushellProvider {
    null = null;
    structured = provider: {
      text = renderNushellTheme (theme.requireStructuredOption provider "colors");
    };
    asset = provider: {
      source = theme.requireAssetSource provider;
    };
    default = _: null;
  };
  configNu = ''
    use std/config *

    #--- Environment Variables ---#
    $env.EDITOR = "hx"
    $env.VOLUME_STEP = 5
    $env.BRIGHTNESS_STEP = 5

    $env.DOTFILES_THEME_FAMILY = ${builtins.toJSON theme.source.family}
    $env.DOTFILES_THEME_FLAVOR = ${builtins.toJSON theme.source.variant}
    $env.DOTFILES_THEME_ACCENT = ${builtins.toJSON theme.source.accent}
    $env.NVIM_COLORSCHEME = ${builtins.toJSON neovimColorscheme}

    #--- Aliases ---#
    alias cl = clear
    alias lgit = lazygit
    alias grep = grep --color=auto
    alias ll = ls -l
    alias fg = job unfreeze

    #--- Settings ---#
    $env.config.buffer_editor = "hx"
    $env.config.history.file_format = "sqlite"

    #--- Hooks ---#
    # NixOS command_not_found Hook
    $env.config.hooks.command_not_found = {
      |command_name|
      print (command-not-found $command_name | str trim)
    }
    # $env.config.hooks.command_not_found = source "command-not-found.nu"

    $env.config = ($env.config? | default {})
    $env.config.hooks = ($env.config.hooks? | default {})
    $env.config.hooks.pre_prompt = (
      $env.config.hooks.pre_prompt?
      | default []
      | append {||
          ${lib.getExe pkgs.direnv} export json
          | from json --strict
          | default {}
          | items {|key, value|
              let value = do (
                {
                  "PATH": {
                    from_string: {|s| $s | split row (char esep) | path expand --no-symlink }
                    to_string: {|v| $v | path expand --no-symlink | str join (char esep) }
                  }
                }
                | merge ($env.ENV_CONVERSIONS? | default {})
                | get ([[value, optional, insensitive]; [$key, true, true] [from_string, true, false]] | into cell-path)
                | if ($in | is-empty) { {|x| $x} } else { $in }
              ) $value
              [ $key $value ]
            }
          | into record
          | load-env
      }
    )

    #--- Miscellaneous Setups ---#

    # Starship Setup
    mkdir ($nu.data-dir | path join "vendor/autoload")
    starship init nu | save -f ($nu.data-dir | path join "vendor/autoload/starship.nu")

    # Zoxide Setup
    # zoxide init nushell | save -f ($nu.default-config-dir | path join "zoxide.nu")
    # source ($nu.default-config-dir | path join "zoxide.nu")
    const ZOXIDE_PATH = ($nu.default-config-dir | path join "zoxide.nu")
    if not ($ZOXIDE_PATH | path exists) {
        zoxide init nushell | save -f $ZOXIDE_PATH
    }
    const NOZOXIDE = "/dev/null"
    const zoxide_file = (if ($ZOXIDE_PATH | path exists) { $ZOXIDE_PATH } else { $NOZOXIDE })
    source $zoxide_file

    # Yazi shell wrapper
    def --env y [...args] {
    	let tmp = (mktemp -t "yazi-cwd.XXXXXX")
    	yazi ...$args --cwd-file $tmp
    	let cwd = (open $tmp)
    	if $cwd != "" and $cwd != $env.PWD {
    		cd $cwd
    	}
    	rm -fp $tmp
    }

    # Theme fragments
  ''
  + lib.optionalString (!theme.isHandledByStylix nushellProvider) ''
    const THEME_NU = ${builtins.toJSON themeNuPath}
    if ($THEME_NU | path exists) {
        source $THEME_NU
    }

  ''
  + lib.optionalString (!theme.isHandledByStylix fzfProvider) ''
    const FZF_THEME_NU = ${builtins.toJSON fzfThemeNuPath}
    if ($FZF_THEME_NU | path exists) {
        source $FZF_THEME_NU
    }

  ''
  + ''

    #--- Custom Commands ---#
    use hhx.nu

    #--- Keybinds ---#
    $env.config.keybindings ++= [
      {
        name: "unfreeze",
        modifier: control,
        keycode: "char_z",
        event: {
          send: executehostcommand,
          cmd: "job unfreeze"
        },
        mode: emacs
      }
    ]
  '';
in
{
  options.modules.${program} = {
    enable = mkEnableOption "enables ${program} config";
  };
  config = mkIf program-module.enable {
    programs.${program}.enable = true;
    xdg.configFile = {
      "${program}/config.nu".text = configNu;
      "${program}/hhx.nu".source = ./hhx.nu;
      "${program}/command-not-found.nu".source = ./command-not-found.nu;
    } // lib.optionalAttrs (nushellTheme != null) {
      "dotfiles-theme/nushell.nu" = nushellTheme;
    };
  };
}
