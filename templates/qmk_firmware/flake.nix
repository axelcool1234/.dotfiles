{
  description = "QMK environment for the Piantor keymap in your fork";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { nixpkgs, ... }:
    let
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];
    in
    {
      devShells = nixpkgs.lib.genAttrs systems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };

          piantorKeyboard = "beekeeb/piantor";
          piantorKeymap = "axel_lab";
          piantorKeymapDir = "keyboards/${piantorKeyboard}/keymaps/${piantorKeymap}";

          piantor-compile = pkgs.writeShellScriptBin "piantor-compile" ''
            #!/usr/bin/env bash
            set -euo pipefail

            qmk compile -kb "${piantorKeyboard}" -km "${piantorKeymap}" "$@"
          '';

          piantor-edit = pkgs.writeShellScriptBin "piantor-edit" ''
            #!/usr/bin/env bash
            set -euo pipefail

            editor="''${EDITOR:-''${VISUAL:-hx}}"
            target_dir="${piantorKeymapDir}"

            if [ ! -d "$target_dir" ]; then
              echo "Expected Piantor keymap directory at '$target_dir'" >&2
              echo "Run this from the root of your qmk_firmware fork." >&2
              exit 1
            fi

            exec "$editor" \
              "$target_dir/keymap.c" \
              "$target_dir/config.h" \
              "$target_dir/rules.mk" \
              "$target_dir/defines.h" \
              "$target_dir/sym_word.h" \
              "$target_dir/sym_word.c"
          '';
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              clang-tools
              keymapviz
              piantor-compile
              piantor-edit
              qmk
            ];
          };
        }
      );
    };
}
