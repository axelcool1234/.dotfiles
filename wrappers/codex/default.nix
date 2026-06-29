{
  config,
  lib,
  myLib,
  selfPkgs,
  ...
}:
let
  discoveredSkills = myLib.importTree.dirsWithFile ./skills "SKILL.md";
  runtimeHome = config.outOfStoreConfig;
  persistRoot =
    assert lib.hasPrefix ''${"$"}HOME/'' runtimeHome;
    lib.removePrefix ''${"$"}HOME/'' runtimeHome;
in
{
  imports = [
    ./module.nix
  ];

  config = {
    env = {
      LEAN4_PLUGIN_ROOT = "${selfPkgs."lean4-skill"}";
      LEAN4_SCRIPTS = "${selfPkgs."lean4-skill"}/lib/scripts";
      LEAN4_REFS = "${selfPkgs."lean4-skill"}/references";
    };

    settings = lib.mkDefault {
      model = "gpt-5.4";
      model_reasoning_effort = "high";

      mcp_servers = {
        nixos = {
          command = "nix";
          args = [
            "run"
            "github:utensils/mcp-nixos"
            "--"
          ];
        };

        "lean-lsp" = {
          command = "${selfPkgs."lean-lsp-mcp"}/bin/lean-lsp-mcp";
        };

      };

      projects."/home/axelcool1234/.dotfiles".trust_level = "trusted";

      tui = {
        terminal_title = [
          "activity"
          "app-name"
        ];
        status_line = [
          "current-dir"
          "model-with-reasoning"
          "task-progress"
          "git-branch"
          "run-state"
          "permissions"
          "approval-mode"
          "context-remaining"
          "five-hour-limit"
          "weekly-limit"
          "thread-title"
        ];
        status_line_use_colors = true;
        pet = "null-signal";
      };
    };

    skills =
      (lib.mapAttrs (_name: source: { inherit source; }) discoveredSkills)
      // {
        lean4.source = selfPkgs."lean4-skill";
      };

    passthru.persist = {
      homeDirectories = [
        # Codex atomically replaces auth/state files, so file-level bind mounts
        # can fail with EBUSY during login.
        persistRoot
      ];
      homeFiles = [ ];
    };
  };
}
