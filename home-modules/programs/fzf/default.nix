{ pkgs, lib, config, theme, ... }:
with lib;
let
  program = "fzf";
  program-module = config.modules.${program};
  fzfProvider = theme.lookupProvider program;

  # Convert a structured provider's raw default option string into a Nushell
  # fragment that appends those flags onto the current FZF_DEFAULT_OPTS.
  renderFzfNu = defaultOpts:
    let
      normalizedOpts = lib.removePrefix "$FZF_DEFAULT_OPTS " defaultOpts;
    in
    ''
      let extra_fzf_opts = ${builtins.toJSON normalizedOpts}
      $env.FZF_DEFAULT_OPTS = ([($env.FZF_DEFAULT_OPTS? | default "") $extra_fzf_opts] | where {|x| $x != "" } | str join " ")
    '';

  # Adapt upstream shell assets that export FZF_DEFAULT_OPTS into the same
  # Nushell fragment format used by this module's runtime handoff file.
  renderFzfShSource = source:
    pkgs.runCommandLocal "dotfiles-fzf.nu" { } ''
      awk '
        BEGIN {
          printf "let extra_fzf_opts = \""
          sep = ""
        }

        {
          gsub(/\r/, "")
          sub(/^export FZF_DEFAULT_OPTS="\$FZF_DEFAULT_OPTS[[:space:]]*/, "")
          sub(/[[:space:]]*\\[[:space:]]*$/, "", $0)
          sub(/[[:space:]]*"$/, "", $0)
          gsub(/[[:space:]]+/, " ", $0)
          sub(/^ /, "", $0)
          sub(/ $/, "", $0)

          if ($0 != "") {
            printf "%s%s", sep, $0
            sep = " "
          }
        }

        END {
          print "\""
          print "$env.FZF_DEFAULT_OPTS = ([($env.FZF_DEFAULT_OPTS? | default \"\") $extra_fzf_opts] | where {|x| $x != \"\" } | str join \" \")"
        }
      ' ${source} > "$out"
    '';

  # Render structured theme data directly into the Nushell handoff file when
  # the selected provider exposes FZF_DEFAULT_OPTS as plain option text.
  fzfThemeText =
    let
      defaultOpts = theme.lookupStructuredOption fzfProvider "defaultOpts";
    in
    if defaultOpts != null then renderFzfNu defaultOpts else null;

  # Realize asset-backed themes into the same handoff path, converting legacy
  # shell exports to Nushell only when the upstream asset is a .sh file.
  fzfThemeSource =
    if theme.providerIsAsset fzfProvider then
      let
        source = theme.requireAssetSource fzfProvider;
      in
      if lib.hasSuffix ".sh" fzfProvider.source then
        renderFzfShSource source
      else
        source
    else
      null;
in
{
  options.modules.${program} = {
    enable = mkEnableOption "enables ${program} config";
  };
  config = mkIf program-module.enable {
    programs.${program} = {
      enable = true;
    };
    xdg.configFile =
      lib.optionalAttrs (fzfThemeText != null) {
        "dotfiles-theme/fzf.nu".text = fzfThemeText;
      }
      // lib.optionalAttrs (fzfThemeText == null && fzfThemeSource != null) {
        "dotfiles-theme/fzf.nu".source = fzfThemeSource;
      };
  };
}
