{
  config,
  hostVars,
  lib,
  myLib,
  pkgs,
  selfPkgs,
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
  imports = [ ./module.nix ];

  config = {
    runtimePkgs = [ selfPkgs.jjui ];

    settings = {
      "$schema" = "https://pi.dev/schemas/settings.schema.json";
      defaultProvider = lib.mkDefault "openai";
      defaultModel = lib.mkDefault "gpt-6.1-sol";
      defaultThinkingLevel = lib.mkDefault "high";
      defaultProjectTrust = lib.mkDefault "always";
      enableInstallTelemetry = lib.mkDefault false;

      skills = lib.mkDefault (
        lib.mapAttrsToList (_name: source: toString source) discoveredSkills
        ++ [ "${janeStreetSkills}/socratic-tutor" ]
      );
      extensions = [ (toString ./extensions/jjui.ts) ];

      theme = lib.mkIf (hostVars.desktopShell == "noctalia") (lib.mkDefault "noctalia");

      packages = lib.mkDefault [
        "npm:@tmustier/pi-usage-extension@0.10.2"
        "git:github.com/m7l5/pi-msg@d65a741887f0c3cbf749b7f4a8fa017422acd10a"
        "npm:pi-web-access@0.47.0"
        "npm:pi-background-tasks@2.6.10"
        "npm:pi-subagents@0.84.0"
        "npm:@juicesharp/rpiv-ask-user-question@2.15.0"
        "npm:@plannotator/pi-extension@0.28.49"
        "npm:@juicesharp/rpiv-todo@2.15.0"
        "npm:pi-lens@4.4.8"
        "npm:pi-btw@0.8.1"
        "npm:pi-advisor-flow@0.14.4"
      ];
    };

    constructFiles.advisorConfig = {
      relPath = "${config.binName}-config/advisor.json";
      output = lib.mkOverride 0 config.generatedConfig.output;
      content = builtins.toJSON {
        advisor = "openai-codex/gpt-6.1-sol";
        advisorEffort = "high";
        # We intentionally want a second opinion from the same model.
        advisorDisableSameModel = false;
      };
    };

    runShell = lib.mkIf config.autoSyncConfig [
      {
        name = "SYNC_PI_ADVISOR_CONFIG";
        data = ''${config.constructFiles.syncPiConfig.path} advisor.json ${config.constructFiles.advisorConfig.path}'';
      }
    ];

    passthru.persist = {
      homeDirectories = [
        persistRoot
        # pi-msg deliberately stores its sockets, registry, and offline inbox
        # beside the agent directory rather than underneath it.
        ".pi/msg"
      ];
      homeFiles = [ ];
    };
  };
}
