{ writeShellApplication, coreutils, findutils, fzf, gnused, gum, jq, nix, ns }:

writeShellApplication {
  name = "ts";
  runtimeInputs = [
    coreutils
    findutils
    fzf
    gnused
    gum
    jq
    nix
    ns
  ];

  text = ''
    # ts: theme switch
    #
    # Interactive theme switch script for this dotfiles repo.
    #
    # Flow:
    # 1. Choose either a family theme or a Stylix/Base16 theme.
    # 2. Select the concrete theme with fzf.
    # 3. Rewrite themes/selected_theme.nix with that selection.
    # 4. Run `ns` to perform the paired NixOS and Home Manager switches.
    # 5. Refresh the live Hyprland cursor when possible.

    set -euo pipefail

    write_family_theme() {
      family="$1"
      variant="$2"
      accent="''${3:-}"

      if [ -n "$accent" ]; then
        cat > "$repo_root/themes/selected_theme.nix" <<EOF
{ themeLib, pkgs }:
themeLib.withRuntime (themeLib.families.''${family}.mk {
  source = {
    variant = "$variant";
    accent = "$accent";
  };
})
EOF
      else
        cat > "$repo_root/themes/selected_theme.nix" <<EOF
{ themeLib, pkgs }:
themeLib.withRuntime (themeLib.families.''${family}.mk {
  source = {
    variant = "$variant";
  };
})
EOF
      fi
    }

    write_stylix_theme() {
      scheme_file="$1"

      cat > "$repo_root/themes/selected_theme.nix" <<EOF
{ themeLib, pkgs }:
themeLib.withRuntime (themeLib.stylix.mk {
  source.base16Scheme = "\''${pkgs.base16-schemes}/share/themes/$scheme_file";
})
EOF
    }

    choose_family_theme() {
      local choice family variant accent

      choice="$({
        family_json="$(nix eval --json --impure --expr '
          let
            pkgs = import <nixpkgs> {};
            themeLib = import ./themes { lib = pkgs.lib; };
          in builtins.mapAttrs (_: family: {
            variants = family.variants or [ ];
            accents = family.accents or [ ];
          }) themeLib.families
        ')"

        printf '%s' "$family_json" | jq -r '
          to_entries[] as $family |
          $family.value.variants[] as $variant |
          if ($family.value.accents | length) == 0 then
            [$family.key, $variant, "", ($family.key + "-" + $variant)]
          else
            $family.value.accents[] as $accent |
            [$family.key, $variant, $accent, ($family.key + "-" + $variant + "-" + $accent)]
          end |
          @tsv
        '
      } | fzf --delimiter '\t' --with-nth 4 --prompt 'family theme > ' --height 40%)"

      [ -n "$choice" ] || exit 1

      family="$(printf '%s' "$choice" | cut -f1)"
      variant="$(printf '%s' "$choice" | cut -f2)"
      accent="$(printf '%s' "$choice" | cut -f3)"

      write_family_theme "$family" "$variant" "$accent"
    }

    choose_stylix_theme() {
      local base16_store themes_dir scheme_file

      base16_store="$(nix build --no-link --print-out-paths nixpkgs#base16-schemes | tail -n1)"
      themes_dir="$base16_store/share/themes"

      scheme_file="$(find "$themes_dir" -maxdepth 1 -type f \( -name '*.yaml' -o -name '*.yml' \) -printf '%f\n' | sort | fzf --prompt 'stylix theme > ' --height 40%)"

      [ -n "$scheme_file" ] || exit 1

      write_stylix_theme "$scheme_file"
    }

    refresh_cursor() {
      if [ -z "''${HYPRLAND_INSTANCE_SIGNATURE:-}" ] || ! command -v hyprctl >/dev/null 2>&1; then
        return 0
      fi

      theme="''${HYPRCURSOR_THEME:-}"
      size="''${HYPRCURSOR_SIZE:-}"

      if [ -z "$theme" ]; then
        theme="''${XCURSOR_THEME:-}"
      fi

      if [ -z "$size" ]; then
        size="''${XCURSOR_SIZE:-}"
      fi

      if [ -z "$theme" ]; then
        theme="$(${gnused}/bin/sed -n 's/^HYPRCURSOR_THEME=//p' /etc/set-environment | head -n1)"
      fi

      if [ -z "$size" ]; then
        size="$(${gnused}/bin/sed -n 's/^HYPRCURSOR_SIZE=//p' /etc/set-environment | head -n1)"
      fi

      if [ -z "$theme" ]; then
        theme="$(${gnused}/bin/sed -n 's/^XCURSOR_THEME=//p' /etc/set-environment | head -n1)"
      fi

      if [ -z "$size" ]; then
        size="$(${gnused}/bin/sed -n 's/^XCURSOR_SIZE=//p' /etc/set-environment | head -n1)"
      fi

      if [ -z "$theme" ] && [ -f "$HOME/.config/gtk-3.0/settings.ini" ]; then
        theme="$(${gnused}/bin/sed -n 's/^gtk-cursor-theme-name=//p' "$HOME/.config/gtk-3.0/settings.ini" | head -n1)"
      fi

      if [ -z "$size" ] && [ -f "$HOME/.config/gtk-3.0/settings.ini" ]; then
        size="$(${gnused}/bin/sed -n 's/^gtk-cursor-theme-size=//p' "$HOME/.config/gtk-3.0/settings.ini" | head -n1)"
      fi

      if [ -n "$theme" ] && [ -n "$size" ]; then
        hyprctl setcursor "$theme" "$size"
      fi
    }

    repo_root="$HOME/.dotfiles"

    if [ ! -d "$repo_root" ]; then
      echo "dotfiles repo not found at $repo_root" >&2
      exit 1
    fi

    cd "$repo_root"

    theme_mode="$(gum choose 'family' 'stylix' --header 'Theme mode')"

    case "$theme_mode" in
      family)
        choose_family_theme
        ;;
      stylix)
        choose_stylix_theme
        ;;
      *)
        exit 1
        ;;
    esac

    ns
    refresh_cursor
  '';
}
