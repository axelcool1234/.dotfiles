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
  mergeTomlPython = pkgs.python3.withPackages (ps: [ ps."tomli-w" ]);
  runtimeCodeHome = config.outOfStoreConfig;
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
        Bootstrap Every Code config written to the generated `config.toml`.

        When `outOfStoreConfig` and `autoCopyConfig` are enabled, this seeds a
        runtime `CODE_HOME/config.toml` if it does not already exist. Existing
        runtime config is preserved so Code can continue to manage its mutable
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
      default = ''${"$"}HOME/.code'';
      example = ''${"$"}HOME/.local/share/every-code'';
      description = ''
        Writable runtime Code home. Defaults to `~/.code`.

        Code writes to its home directory at runtime, so this must point to a
        writable location. The wrapper exports `CODE_HOME` to this path and can
        seed and refresh wrapper-managed files there on startup while
        preserving existing mutable runtime config.
      '';
    };

    autoCopyConfig = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to automatically provision and refresh wrapper-managed files in
        the active runtime Code home on startup.

        Existing `config.toml` is preserved after the first seed so Code does
        not lose runtime-managed changes. The wrapper still refreshes
        wrapper-managed skill content and applies optional merged config
        fragments.
      '';
    };

    extraConfigFiles = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "$HOME/.cache/noctalia/every-code-theme.toml" ];
      description = ''
        Optional TOML fragments merged into the runtime `config.toml` if the
        referenced files exist.

        These files are parsed at startup and deep-merged over the existing
        runtime config, then the whole file is rewritten. This preserves
        runtime-managed settings outside the overridden subtrees, but comments
        and original formatting are not preserved.

        Removing a setting from an extra config fragment does not remove any
        previously merged value already present in `config.toml`; merge updates
        and replaces keys, but it does not infer deletions.
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
            wrappers.code.skills contains unsafe skill directory names: ${lib.concatStringsSep ", " invalidNames}
            Use only letters, digits, `.`, `_`, and `-`, with no `/`.
          ''
        else if missingSkillMd == [ ] then
          skills
        else
          throw ''
            wrappers.code.skills entries must point to directories containing SKILL.md.
            Missing SKILL.md for: ${lib.concatStringsSep ", " missingSkillMd}
          '';
      description = ''
        Declarative Every Code skills. Each attribute name becomes a skill
        directory under `skills/declarative/` in the runtime Code home;
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
        The derivation output for the generated Code configuration.
      '';
    };

  };

  config = {
    package = lib.mkDefault inputs.llm-agents.packages.${system}.code;

    envDefault.CODE_HOME = {
      data = config.outOfStoreConfig;
      esc-fn = wlib.escapeShellArgWithEnv;
    };

    drv.extraSettings = config.extraSettings;
    drv.passAsFile = lib.mkIf (config.extraSettings != "") [ "extraSettings" ];

    passthru = {
      generatedConfig = config.constructFiles.generatedConfig.outPath;
      generatedSkills = generatedSkillsOutPath;
      copyCodeHome = config.constructFiles.copyCodeHome.outPath;
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
        key = "generatedCodeSkills";
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

      copyCodeHome = {
        key = "copyCodeHome";
        relPath = "bin/copy-code-home";
        builder = ''mkdir -p "$(dirname "$2")" && cp "$1" "$2" && chmod +x "$2"'';
        content = ''
          #!${pkgs.bash}/bin/bash
          set -euo pipefail

          code_home="''${CODE_HOME:-${runtimeCodeHome}}"
          config_path="$code_home/config.toml"
          base_config_path="${config.constructFiles.generatedConfig.path}"
          mkdir -p "$(dirname "$config_path")"
          # Preserve mutable runtime config after the initial seed.
          if [ ! -e "$config_path" ] && [ ${lib.escapeShellArg (if config.extraConfigFiles == [ ] then "1" else "0")} = 1 ]; then
            cat "$base_config_path" > "$config_path"
            chmod 600 "$config_path"
          fi

          ${lib.optionalString (config.extraConfigFiles != [ ]) ''
            # Every Code currently lacks a native include/import mechanism for
            # additional TOML config files, so the wrapper has to merge runtime
            # fragments into the mutable config on startup.
            # Merge runtime TOML fragments into the mutable config instead of
            # managing a raw text block inside the file.
            ${mergeTomlPython}/bin/python - "$config_path" "$base_config_path" ${lib.concatMapStringsSep " " lib.escapeShellArg config.extraConfigFiles} <<'PY'
import os
import stat
import sys
import tomllib
from pathlib import Path

import tomli_w


def load_toml(path: Path) -> dict:
    with path.open("rb") as handle:
        data = tomllib.load(handle)
    if not isinstance(data, dict):
        raise TypeError(f"{path} did not parse to a TOML table")
    return data


def deep_merge(base: dict, overlay: dict) -> dict:
    # Merge overlays into the existing runtime config without trying to infer
    # deletions from missing keys.
    for key, value in overlay.items():
        if isinstance(value, dict) and isinstance(base.get(key), dict):
            deep_merge(base[key], value)
        else:
            base[key] = value
    return base


config_path = Path(sys.argv[1])
bootstrap_path = Path(sys.argv[2])
fragment_paths = sys.argv[3:]

if config_path.exists():
    merged = load_toml(config_path)
else:
    merged = load_toml(bootstrap_path)

for raw_path in fragment_paths:
    fragment_path = Path(os.path.expandvars(raw_path)).expanduser()
    if fragment_path.is_file():
        deep_merge(merged, load_toml(fragment_path))

config_path.parent.mkdir(parents=True, exist_ok=True)
config_path.write_text(tomli_w.dumps(merged), encoding="utf-8")
os.chmod(config_path, stat.S_IRUSR | stat.S_IWUSR)
PY
          ''}

          skills_path="$code_home/skills/declarative"
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
        name = "COPY_CODE_HOME";
        data = ''${config.constructFiles.copyCodeHome.path}'';
      }
    ];
    meta.description = ''
      Wrapper module for Every Code / just-every/code.

      Generates bootstrap config in the store, supports a structured
      `settings` attrset plus appended TOML via `extraSettings`, optional
      runtime `CODE_HOME` relocation, and can optionally seed generated config
      and declared skills into the active Code home on startup while
      preserving existing runtime-managed config.
    '';
  };
}
