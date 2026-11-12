{
  config,
  lib,
  myLib,
  pkgs,
  ...
}:
let
  discoveredSkills = myLib.importTree.dirsWithFile ../../skills "SKILL.md";
  janeStreetSkills = pkgs.fetchFromGitHub {
    owner = "janestreet";
    repo = "agent_skills";
    rev = "7c6715c29548a3b39d4a9545c698ee4fd17a7213";
    hash = "sha256-bKGKDaK2pSJsp5uVMUQDcj8J+N9nX2fDdeU1DXM2qLw=";
  };
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
    settings = lib.mkDefault {
      approval_policy = "never";
      model = "gpt-6.1-sol";
      model_reasoning_effort = "high";
      sandbox_mode = "danger-full-access";

      projects."/home/axelcool1234/.dotfiles".trust_level = "trusted";

      tui = {
        theme = "noctalia";
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

    skills = lib.mapAttrs (_name: source: { inherit source; }) discoveredSkills // {
      socratic-tutor.source = "${janeStreetSkills}/socratic-tutor";
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
