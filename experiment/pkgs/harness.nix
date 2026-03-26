{
  pkgs,
  inputs,
  ...
}:
inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.code
