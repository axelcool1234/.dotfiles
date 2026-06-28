{
  config,
  inputs,
  lib,
  pkgs,
  system,
  wlib,
  ...
}:
let
  tomlFmt = pkgs.formats.toml { };
  runtimeCodexHome = config.outOfStoreConfig;
  generatedSkillsDir = "${config.binName}-skills";
  generatedSkillsPath = dirOf config.constructFiles.generatedSkills.path;
  generatedSkillsOutPath = dirOf config.constructFiles.generatedSkills.outPath;
  validSkillName = name: builtins.match "^[A-Za-z0-9][A-Za-z0-9._-]*$" name != null;
in
{
  imports = [ wlib.modules.default ];

  options = {
    settings = lib.mkOption {
      type = tomlFmt.type;
      default = { };
      description = ''
        Bootstrap Codex config written to the generated `config.toml`.

        When `outOfStoreConfig` and `autoCopyConfig` are enabled, this seeds a
        runtime `CODEX_HOME/config.toml` if it does not already exist. Existing
        runtime config is preserved so Codex can continue to manage its mutable
        settings at runtime.
      '';
    };

    extraSettings = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = ''
        Extra TOML appended to the generated bootstrap `config.toml` after
        `settings`.

        Use this as an escape hatch for configuration that is inconvenient to
        express through the structured `settings` attrset.
      '';
    };

    outOfStoreConfig = lib.mkOption {
      type = lib.types.str;
      default = ''${"$"}HOME/.codex'';
      example = ''${"$"}HOME/.local/share/codex'';
      description = ''
        Writable runtime Codex home. Defaults to `~/.codex`.

        Codex writes to its home directory at runtime, so this must point to a
        writable location. The wrapper exports `CODEX_HOME` to this path and can
        seed and refresh wrapper-managed files there on startup while
        preserving existing mutable runtime config.
      '';
    };

    autoCopyConfig = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to automatically provision and refresh wrapper-managed files in
        the active runtime Codex home on startup.

        Existing `config.toml` is preserved after the first seed so Codex does
        not lose runtime-managed changes. The wrapper still refreshes
        wrapper-managed skill content.
      '';
    };

    skills = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule ({ ... }: {
        options = {
          source = lib.mkOption {
            type = lib.types.oneOf [
              lib.types.path
              lib.types.package
            ];
            description = "Path or package providing the skill directory containing SKILL.md.";
          };
        };
      }));
      default = { };
      apply =
        skills:
        let
          invalidNames = builtins.filter (name: !validSkillName name) (builtins.attrNames skills);
          missingSkillMd = builtins.filter (
            name: !(builtins.pathExists "${skills.${name}.source}/SKILL.md")
          ) (builtins.attrNames skills);
        in
        if invalidNames != [ ] then
          throw ''
            wrappers.codex.skills contains unsafe skill directory names: ${lib.concatStringsSep ", " invalidNames}
            Use only letters, digits, `.`, `_`, and `-`, with no `/`.
          ''
        else if missingSkillMd == [ ] then
          skills
        else
          throw ''
            wrappers.codex.skills entries must point to directories containing SKILL.md.
            Missing SKILL.md for: ${lib.concatStringsSep ", " missingSkillMd}
          '';
      description = ''
        Declarative Codex skills. Each attribute name becomes a skill
        directory under `skills/declarative/` in the runtime Codex home;
        declaring a skill here installs it into the Nix-managed declarative
        skills subtree. The wrapper owns `skills/declarative/` and may remove
        undeclared entries there; runtime-managed skills must live outside that
        subtree. Each value must point to a skill folder containing `SKILL.md`.
        Derivation outputs are allowed when they are rooted at the skill
        directory itself.
      '';
    };

    generatedConfig.output = lib.mkOption {
      type = lib.types.str;
      default = config.outputName;
      description = ''
        The derivation output for the generated Codex configuration.
      '';
    };

  };

  config = {
    package = lib.mkDefault inputs.llm-agents.packages.${system}.codex;

    envDefault.CODEX_HOME = {
      data = config.outOfStoreConfig;
      esc-fn = wlib.escapeShellArgWithEnv;
    };

    drv.extraSettings = config.extraSettings;
    drv.passAsFile = lib.mkIf (config.extraSettings != "") [ "extraSettings" ];

    passthru = {
      generatedConfig = config.constructFiles.generatedConfig.outPath;
      generatedSkills = generatedSkillsOutPath;
      copyCodexHome = config.constructFiles.copyCodexHome.outPath;
    };

    constructFiles = {
      generatedConfig = {
        relPath = "${config.binName}-config/config.toml";
        output = lib.mkOverride 0 config.generatedConfig.output;
        content = builtins.toJSON config.settings;
        builder = ''
          mkdir -p "$(dirname "$2")" && \
          ${pkgs.remarshal}/bin/json2toml "$1" "$2"
          ${lib.optionalString (config.extraSettings != "") ''
            && \
            cat "$extraSettingsPath" >> "$2"
          ''}
        '';
      };

      generatedSkills = {
        key = "generatedCodexSkills";
        relPath = "${generatedSkillsDir}/.keep";
        content = lib.concatLines (
          lib.mapAttrsToList (
            name: skill:
            "sync_skill ${lib.escapeShellArg name} ${lib.escapeShellArg "${skill.source}/"}"
          ) config.skills
        );
        builder = ''
          root="$(dirname "$2")"
          mkdir -p "$root"

          sync_skill() {
            local name="$1"
            local source="$2"
            mkdir -p "$root/$name"
            ${pkgs.rsync}/bin/rsync -a --delete "$source" "$root/$name/"
          }

          . "$1"
          : > "$2"
        '';
      };

      copyCodexHome = {
        key = "copyCodexHome";
        relPath = "bin/copy-codex-home";
        builder = ''mkdir -p "$(dirname "$2")" && cp "$1" "$2" && chmod +x "$2"'';
        content = ''
          #!${pkgs.bash}/bin/bash
          set -euo pipefail

          codex_home="''${CODEX_HOME:-${runtimeCodexHome}}"
          config_path="$codex_home/config.toml"
          base_config_path="${config.constructFiles.generatedConfig.path}"
          mkdir -p "$(dirname "$config_path")"
          # Preserve mutable runtime config after the initial seed.
          if [ ! -e "$config_path" ]; then
            cat "$base_config_path" > "$config_path"
            chmod 600 "$config_path"
          fi

          skills_path="$codex_home/skills/declarative"
          mkdir -p "$skills_path"
          # This subtree is reserved for Nix-declared skills, so convergence is
          # intentional and unmanaged entries here are removed.
          ${pkgs.rsync}/bin/rsync -a --delete --exclude=.keep "${generatedSkillsPath}/" "$skills_path/"
        '';
      };
    }
    ;

    runShell = lib.mkIf config.autoCopyConfig [
      {
        name = "COPY_CODEX_HOME";
        data = ''${config.constructFiles.copyCodexHome.path}'';
      }
    ];
    meta.description = ''
      Wrapper module for OpenAI Codex CLI.

      Generates bootstrap config in the store, supports a structured
      `settings` attrset plus appended TOML via `extraSettings`, optional
      runtime `CODEX_HOME` relocation, and can optionally seed generated config
      and declared skills into the active Codex home on startup while
      preserving existing runtime-managed config.
    '';
  };
}
