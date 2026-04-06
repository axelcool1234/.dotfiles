{
  config,
  hostVars,
  lib,
  myLib,
  selfPkgs,
  ...
}:
let
  useNoctaliaTheme = hostVars.desktop-shell == "noctalia-shell";
  discoveredSkills = myLib.importTree.dirsWithFile ./skills "SKILL.md";
  runtimeHome = config.outOfStoreConfig;
  persistRoot =
    assert lib.hasPrefix ''${"$"}HOME/'' runtimeHome;
    lib.removePrefix ''${"$"}HOME/'' runtimeHome;

  persistPath = suffix:
    if suffix == null then
      persistRoot
    else
      "${persistRoot}/${suffix}";
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
      preferred_model_reasoning_effort = "high";

      tui = {
        review_auto_resolve = false;
        auto_review_enabled = false;
      };

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
    };

    skills =
      (lib.mapAttrs (_name: source: { inherit source; }) discoveredSkills)
      // {
        lean4.source = selfPkgs."lean4-skill";
      };

    extraConfigFiles = lib.optionals useNoctaliaTheme [
      "$HOME/.cache/noctalia/every-code-theme.toml"
    ];

    passthru.persist = {
      homeDirectories = [
        (persistPath "debug_logs")
        (persistPath "sessions")
        (persistPath "state")
        (persistPath "usage")
        (persistPath "working")
      ];
      homeFiles = [
        (persistPath "auth.json")
        (persistPath "auth_accounts.json")
        (persistPath "cleanup-state.json")
        (persistPath "cleanup.lock")
        (persistPath "history.jsonl")
        (persistPath "models_cache.json")
        (persistPath "version.json")
      ];
    };
  };
}
