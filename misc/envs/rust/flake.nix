{
  description = "Rust Environment";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
  };

  outputs = { self, nixpkgs, ... }:
  let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
  in
  {
    devShells.x86_64-linux.default = pkgs.mkShell {
      nativeBuildInputs = with pkgs; [
        rustc
        cargo
        rust-analyzer
        rustfmt
        clippy
        taplo # TOML formatter and lsp
        evcxr # Rust REPL 
        bacon
        grcov

        cargo-watch
        cargo-nextest
        cargo-mutants
        cargo-spellcheck
        cargo-docset
        cargo-audit
        cargo-binutils
        cargo-tarpaulin
        cargo-deny
        cargo-make
        cargo-update
        cargo-edit
        cargo-outdated
        cargo-license
        cargo-cross
        cargo-zigbuild
        cargo-modules
        cargo-bloat
        cargo-unused-features

        lldb_18
        lld_18
        clang_18
      ];
    shellHook = ''
      export HELIX_RUNTIME="$PWD/runtime"
    '';
    };
  };
}
