{
  config,
  lib,
  pkgs,
  wlib,
  ...
}:
let
  inherit (lib)
    concatStringsSep
    escapeShellArg
    literalExpression
    mapAttrsToList
    mkDefault
    mkOption
    nameValuePair
    optional
    optionalString
    removeSuffix
    types
    ;

  cfg = config;

  baseFileType = types.submodule (
    { name, config, ... }:
    {
      options = {
        content = mkOption {
          type = types.lines;
          default = "";
          description = ''
            File contents. When no explicit `path` is provided, this content is
            written to the Nix store and used as the source file.
          '';
        };

        path = mkOption {
          type = wlib.types.stringable;
          description = ''
            Path to the file. By default this is generated from `content`.
          '';
          default = pkgs.writeText name config.content;
          defaultText = lib.literalExpression "pkgs.writeText name <content>";
        };
      };
    }
  );

  rcFileType = types.submodule {
    options = {
      path = mkOption {
        type = types.nullOr wlib.types.stringable;
        default = null;
        description = ''
          External `config.fish` file to source after the wrapper's generated
          fish setup.
        '';
      };

      content = mkOption {
        type = types.lines;
        default = "";
        description = ''
          Extra fish code appended after the wrapper's generated setup and any
          configured `config.fish.path`.
        '';
      };
    };
  };

  abbreviationType = types.submodule ({ name, ... }: {
    options = {
      word = mkOption {
        type = types.str;
        default = name;
        description = "Token or word that triggers the abbreviation.";
      };

      expansion = mkOption {
        type = types.str;
        default = "";
        description = ''
          Expansion text for the abbreviation.

          This is ignored when `function` is set.
        '';
      };

      position = mkOption {
        type = types.enum [
          "command"
          "anywhere"
        ];
        default = "command";
        description = ''
          Where the abbreviation may expand.
        '';
      };

      regex = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          Optional PCRE2 pattern used instead of a literal word match.
        '';
      };

      command = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          Restrict expansion to arguments of the given command.
        '';
      };

      function = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          Fish function used to generate the expansion dynamically.
        '';
      };

      cursor = mkOption {
        type = types.either types.bool types.str;
        default = false;
        description = ''
          Cursor marker for `abbr --set-cursor`.

          Set to `true` to use fish's default `%` marker, or provide a string
          marker explicitly.
        '';
      };
    };
  });

  completionType = types.submoduleWith {
    modules = [
      (builtins.elemAt baseFileType.getSubModules 0)
      ({ name, ... }: {
        options.command = mkOption {
          type = types.str;
          default = removeSuffix ".fish" name;
          description = ''
            Command name that this completion file should target.
          '';
        };
      })
    ];
  };

  pluginType = types.either types.package (
    types.submodule {
      options = {
        src = mkOption {
          type = types.package;
          description = "Plugin package to expose to fish.";
        };

        configDirs = mkOption {
          type = types.listOf types.str;
          default = cfg.pluginConfigDirs;
          description = ''
            Directories inside the plugin package that should be checked for
            fish startup snippets or autoloadable functions.
          '';
        };

        completionDirs = mkOption {
          type = types.listOf types.str;
          default = cfg.pluginCompletionDirs;
          description = ''
            Directories inside the plugin package that should be checked for
            fish completion files.
          '';
        };
      };
    }
  );

  fileNameWithFish = name:
    if lib.hasSuffix ".fish" name then name else "${name}.fish";

  commandFileName = command:
    "${removeSuffix ".fish" command}.fish";

  generatedRoot = "${placeholder config.outputName}/${config.binName}-config";
  generatedConfDir = "${generatedRoot}/conf.d";
  generatedFunctionsDir = "${generatedRoot}/functions";
  generatedCompletionsDir = "${generatedRoot}/completions";

  appendPaths = variable: paths:
    optionalString (paths != [ ]) ''
      set -ga ${variable} ${concatStringsSep " " (map escapeShellArg paths)}
    '';

  constructFileFromPath = relPath: file: {
    inherit relPath;
    content = toString file.path;
    builder = ''
      mkdir -p "$(dirname "$2")"
      cp "$(cat "$1")" "$2"
    '';
  };

  isFunctionDir = dir:
    lib.hasSuffix "/functions" dir || lib.hasSuffix "/vendor_functions.d" dir;

  renderPluginConfigDir = plugin: dir:
    concatStringsSep "\n" (
      builtins.filter (line: line != "") [
        (optionalString (isFunctionDir dir) ''
          if test -d ${plugin.src}/${dir}
            set -ga fish_function_path ${plugin.src}/${dir}
          end
        '')
        (optionalString (!isFunctionDir dir) ''
          for fish_wrapper_conf in ${plugin.src}/${dir}/*.fish
            if test -f $fish_wrapper_conf
              source $fish_wrapper_conf
            end
          end
        '')
      ]
    );

  renderPluginCompletionDir = plugin: dir: ''
    if test -d ${plugin.src}/${dir}
      set -ga fish_complete_path ${plugin.src}/${dir}
    end
  '';

  renderPlugin = plugin:
    concatStringsSep "\n" (
      builtins.filter (line: line != "") (
        map (dir: renderPluginConfigDir plugin dir) plugin.configDirs
        ++ map (dir: renderPluginCompletionDir plugin dir) plugin.completionDirs
      )
    );

  renderedPluginBootstrap = concatStringsSep "\n" (map renderPlugin cfg.plugins);

  renderAbbreviation = abbr:
    let
      position = if abbr.command != null then "anywhere" else abbr.position;
      cursorArgs =
        if abbr.cursor == false then
          [ ]
        else if builtins.isBool abbr.cursor then
          [ "--set-cursor" ]
        else
          [ "--set-cursor=${escapeShellArg abbr.cursor}" ];
      commandArgs = optional (abbr.command != null) "--command"
        ++ optional (abbr.command != null) (escapeShellArg abbr.command);
      regexArgs = optional (abbr.regex != null) "--regex"
        ++ optional (abbr.regex != null) (escapeShellArg abbr.regex);
      bodyArgs =
        if abbr.function != null then
          [ "--function" (escapeShellArg abbr.function) ]
        else
          [ (escapeShellArg abbr.expansion) ];
    in
    concatStringsSep " " (
      [
        "abbr"
        "--add"
        "--position"
        (escapeShellArg position)
      ]
      ++ regexArgs
      ++ commandArgs
      ++ cursorArgs
      ++ [
        "--"
        (escapeShellArg abbr.word)
      ]
      ++ bodyArgs
    );

  renderedAbbreviations = concatStringsSep "\n" (
    mapAttrsToList (_name: abbr: renderAbbreviation abbr) cfg.abbreviations
  );

  renderedAliases = concatStringsSep "\n" (
    mapAttrsToList (
      name: value:
      "alias ${escapeShellArg name}=${escapeShellArg value}"
    ) cfg.shellAliases
  );

  renderedConfigFiles = concatStringsSep "\n" (
    mapAttrsToList (
      name: _file:
      ''source ${escapeShellArg "${generatedConfDir}/${fileNameWithFish name}"}''
    ) cfg.configFiles
  );
in
{
  imports = [ wlib.modules.default ];

  options = {
    "config.fish" = mkOption {
      type = rcFileType;
      default = { };
      description = ''
        Additional `config.fish` content layered into the wrapper-managed fish
        startup.

        The wrapper always sources its own generated fish setup via `-C` after
        fish has already read normal configuration files. If `config.fish.path`
        is set, it is sourced after the wrapper-managed setup and before
        `config.fish.content`.
      '';
    };

    shellInit = mkOption {
      type = types.lines;
      default = "";
      description = ''
        Extra fish code appended at the end of the generated wrapper init file.
      '';
    };

    shellAliases = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "Aliases declared with fish's `alias` helper.";
      example = {
        g = "git";
        ll = "ls -lh";
      };
    };

    abbreviations = mkOption {
      type = types.attrsOf abbreviationType;
      default = { };
      description = ''
        Abbreviations declared with `abbr --add`.
      '';
      example = literalExpression ''
        {
          gs.expansion = "git status";
          v = {
            word = "v";
            expansion = "nvim";
            position = "command";
          };
          bang = {
            word = "!!";
            position = "anywhere";
            function = "last_history_item";
          };
        }
      '';
    };

    configFiles = mkOption {
      type = types.attrsOf baseFileType;
      default = { };
      description = ''
        Fish snippets copied into a wrapper-managed `conf.d` tree and sourced
        after fish's normal startup files have run.
      '';
    };

    functionFiles = mkOption {
      type = types.attrsOf baseFileType;
      default = { };
      description = ''
        Fish function files copied into a wrapper-managed functions directory.
      '';
    };

    completionFiles = mkOption {
      type = types.attrsOf completionType;
      default = { };
      description = ''
        Fish completion files copied into a wrapper-managed completions
        directory.
      '';
    };

    plugins = mkOption {
      type = types.listOf pluginType;
      default = [ ];
      apply = map (
        plugin:
        if plugin ? configDirs then
          plugin
        else
          {
            src = plugin;
            configDirs = cfg.pluginConfigDirs;
            completionDirs = cfg.pluginCompletionDirs;
          }
      );
      description = ''
        Fish plugins to expose to the wrapper.

        Entries may be packages directly or submodules that customize which
        directories are used for snippets, functions, and completions.
      '';
      example = literalExpression ''
        [
          pkgs.fishPlugins.hydro
          {
            src = pkgs.fishPlugins.fzf-fish;
            configDirs = [ "share/fish/vendor_conf.d" ];
            completionDirs = [ "share/fish/vendor_completions.d" ];
          }
        ]
      '';
    };

    pluginConfigDirs = mkOption {
      type = types.listOf types.str;
      default = [
        "share/fish/vendor_functions.d"
        "etc/fish/functions"
        "share/fish/vendor_conf.d"
        "etc/fish/conf.d"
      ];
      description = ''
        Default plugin directories checked for fish functions and startup
        snippets.
      '';
    };

    pluginCompletionDirs = mkOption {
      type = types.listOf types.str;
      default = [
        "share/fish/vendor_completions.d"
        "share/fish/completions"
      ];
      description = ''
        Default plugin directories checked for fish completion files.
      '';
    };
  };

  config = {
    package = mkDefault pkgs.fish;

    flags."-C" = "source ${config.constructFiles.generatedConfig.path}";

    passthru = {
      generatedConfig = config.constructFiles.generatedConfig.outPath;
      shellPath = config.wrapperPaths.relPath;
    };

    constructFiles = {
      generatedConfig = {
        relPath = "${config.binName}-config/config.fish";
        content = concatStringsSep "\n" (
          builtins.filter (part: part != "") [
            # Fish's normal config runs before `-C`, so putting wrapper setup in
            # this generated file keeps it after NixOS and Home Manager startup.
            (appendPaths "fish_function_path" (optional (cfg.functionFiles != { }) generatedFunctionsDir))
            (appendPaths "fish_complete_path" (optional (cfg.completionFiles != { }) generatedCompletionsDir))
            renderedPluginBootstrap
            renderedConfigFiles
            (optionalString (cfg."config.fish".path != null) ''
              source ${escapeShellArg cfg."config.fish".path}
            '')
            cfg."config.fish".content
            renderedAliases
            renderedAbbreviations
            cfg.shellInit
          ]
        );
      };
    }
    // lib.mapAttrs' (
      name: file:
      nameValuePair "config_${name}" (
        constructFileFromPath "${config.binName}-config/conf.d/${fileNameWithFish name}" file
        // {
          key = "config_${name}";
        }
      )
    ) cfg.configFiles
    // lib.mapAttrs' (
      name: file:
      nameValuePair "function_${name}" (
        constructFileFromPath "${config.binName}-config/functions/${fileNameWithFish name}" file
        // {
          key = "function_${name}";
        }
      )
    ) cfg.functionFiles
    // lib.mapAttrs' (
      name: file:
      nameValuePair "completion_${name}" (
        constructFileFromPath "${config.binName}-config/completions/${commandFileName file.command}" file
        // {
          key = "completion_${name}";
        }
      )
    ) cfg.completionFiles;

    meta.description = ''
      Wraps fish while layering wrapper-managed startup after fish's normal
      configuration flow, with fish-specific abstractions for config snippets,
      functions, completions, plugins, aliases, and abbreviations.
    '';
  };
}
