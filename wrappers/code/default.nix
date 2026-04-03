{
  config,
  hostVars,
  inputs,
  lib,
  pkgs,
  system,
  wlib,
  ...
}:
let
  useNoctaliaTheme = hostVars.desktop-shell == "noctalia-shell";
  tomlFormat = pkgs.formats.toml { };
  codeConfigTemplate = tomlFormat.generate "every-code-config.toml" config.settings;
  enabledSkills = lib.filterAttrs (_name: skill: skill.enable) config.skills;
  declarativeSkillNames = lib.attrNames enabledSkills;
  declarativeSkills = pkgs.linkFarm "every-code-skills" (
    lib.mapAttrsToList (name: skill: {
      inherit name;
      path = skill.source;
    }) enabledSkills
  );
in
{
  imports = [ wlib.modules.default ];

  options = {
    settings = lib.mkOption {
      type = tomlFormat.type;
      default = { };
      description = ''
        Declarative Every Code config written to `~/.code/config.toml`.
        This is a base config; runtime state remains under `~/.code/`.
      '';
    };

    skills = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule ({ name, ... }: {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Whether to install the `${name}` skill into ~/.code/skills.";
          };

          source = lib.mkOption {
            type = lib.types.path;
            description = "Path to the skill directory containing SKILL.md.";
          };
        };
      }));
      default = { };
      description = ''
        Declarative Every Code skills. Each attribute name becomes a skill
        directory under `~/.code/skills`, and each value must point to a skill
        folder containing `SKILL.md`.
      '';
    };
  };

  config = {
    package = inputs.llm-agents.packages.${system}.code;

    settings = lib.mkDefault {
      model = "gpt-5.4";
      model_reasoning_effort = "high";
      preferred_model_reasoning_effort = "high";

      mcp_servers.nixos = {
        command = "nix";
        args = [
          "run"
          "github:utensils/mcp-nixos"
          "--"
        ];
      };
    };

    skills.host-audit.source = ./skills/host-audit;
    skills.persistence-migration.source = ./skills/persistence-migration;

    passthru.persist = {
      homeDirectories = [
        ".code/debug_logs"
        ".code/sessions"
        ".code/state"
        ".code/usage"
        ".code/working"
      ];
      homeFiles = [
        ".code/auth.json"
        ".code/auth_accounts.json"
        ".code/cleanup-state.json"
        ".code/cleanup.lock"
        ".code/history.jsonl"
        ".code/models_cache.json"
        ".code/version.json"
      ];
    };

    # Keep ~/.code/config.toml fully declarative: write a generated TOML base
    # on each launch, then optionally append the Noctalia theme fragment.
    runShell = [
      ''
        config_path="$HOME/.code/config.toml"
        base_config_path="${codeConfigTemplate}"
        mkdir -p "$(dirname "$config_path")"
        cp "$base_config_path" "$config_path"
      ''
      ''
        skills_path="$HOME/.code/skills"
        mkdir -p "$skills_path"
      ''
    ] ++ map (
      skillName: ''
        mkdir -p "$HOME/.code/skills/${skillName}"
        ${pkgs.rsync}/bin/rsync -a --delete "${declarativeSkills}/${skillName}/" "$HOME/.code/skills/${skillName}/"
      ''
    ) declarativeSkillNames ++ [
    ] ++ lib.optionals useNoctaliaTheme [
      ''
        config_path="$HOME/.code/config.toml"
        theme_fragment_path="$HOME/.cache/noctalia/every-code-theme.toml"
        if [ -f "$theme_fragment_path" ]; then
          printf '\n' >> "$config_path"
          tr -d '\000' < "$theme_fragment_path" >> "$config_path"
        fi
      ''
    ];
  };
}
