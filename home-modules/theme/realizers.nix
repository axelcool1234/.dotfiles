{ lib, pkgs }:
{
  renderCssColorVariables = colors:
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: value: "@define-color ${name} ${value};") colors
    );

  renderRasiColorVariables = colors:
    ''
      * {
      ${lib.concatStringsSep "\n" (
        lib.mapAttrsToList (name: value: "  ${name}: ${value};") colors
      )}
      }
    '';

  renderFzfNu = defaultOpts:
    let
      normalizedOpts = lib.removePrefix "$FZF_DEFAULT_OPTS " defaultOpts;
    in
    ''
      let extra_fzf_opts = ${builtins.toJSON normalizedOpts}
      $env.FZF_DEFAULT_OPTS = ([($env.FZF_DEFAULT_OPTS? | default "") $extra_fzf_opts] | where {|x| $x != "" } | str join " ")
    '';

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

  emitSourceFile = target: source:
    lib.optionalAttrs (source != null) {
      "${target}".source = source;
    };

  emitTextFile = target: text:
    lib.optionalAttrs (text != null) {
      "${target}".text = text;
    };

  emitTextOrSourceFile = target: text: source:
    lib.optionalAttrs (text != null) {
      "${target}".text = text;
    }
    // lib.optionalAttrs (text == null && source != null) {
      "${target}".source = source;
    };
}
