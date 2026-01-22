{
  description = "LLVM env";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };
        # Build scripts as packages so they can be exposed as apps
        build-llvm-pkg = pkgs.writeShellApplication {
          name = "build-llvm";
          runtimeInputs = with pkgs; [
            cmake
            ninja
            mold
            clang
            clang-tools
            zlib
          ];
          text = ''
            #!/usr/bin/env bash
            set -euo pipefail

            usage() {
              echo "Usage:"
              echo "  build-llvm <path_to_llvm_project>"
              echo "  build-llvm clean"
              exit 1
            }

            if [ "$#" -ne 1 ]; then
              usage
            fi

            if [ "$1" = "clean" ]; then
              echo "Cleaning LLVM build directory"
              rm -rf build/llvm inst
              exit 0
            fi

            llvm_root="$(realpath "$1")"
            src="$llvm_root/llvm"
            build_dir="$(realpath ./build/llvm)"

            if [ ! -d "$src" ]; then
              echo "Error: $src does not exist"
              exit 1
            fi

            mkdir -p "$build_dir"

            cmakeFlags=(
                "-GNinja"
                "-DCMAKE_BUILD_TYPE=Debug"
                 # inst will be our installation prefix
                "-DCMAKE_INSTALL_PREFIX=../inst"
                # Makes compile_commands.json for lsp
                "-DCMAKE_EXPORT_COMPILE_COMMANDS=ON"
                # this makes llvm only to produce code for the given platforms, this saves CPU time, change it to what you need
                "-DLLVM_TARGETS_TO_BUILD=host"
                # Projects to build
                "-DLLVM_ENABLE_PROJECTS=clang;mlir"
                # Faster linker
                "-DLLVM_USE_LINKER=mold"
                # Dynamic Linking
                "-DBUILD_SHARED_LIBS=ON"
                # Prevents debug info duplication, which also speeds up the linker
                # Also improves incremental building speed
                "-DLLVM_USE_SPLIT_DWARF=ON"
                # Optimized TableGen since we're not developing that
                # Also speeds up build time since llvm-tblgen will run faster
                "-DLLVM_OPTIMIZED_TABLEGEN=ON"
                # Newer PassManager (faster compilation speed)
                "-DLLVM_USE_NEWPM=ON"
                "-DLLVM_ENABLE_ASSERTIONS=ON"
                "-DLLVM_ENABLE_EH=ON"
                "-DLLVM_ENABLE_RTTI=ON"
            )

            # Shared libraries
            export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath [ pkgs.zlib ]}:$LD_LIBRARY_PATH"
            export LD_LIBRARY_PATH="${pkgs.stdenv.cc.cc.lib.outPath}/lib:$LD_LIBRARY_PATH"

            # Build
            if [ ! -f "$build_dir/build.ninja" ]; then
              echo "Configuring LLVM with CMake"
              cmake -S "$src" -B "$build_dir" "''${cmakeFlags[@]}"
            else
              echo "LLVM already configured - skipping CMake"
            fi

            echo "Building LLVM"
            ninja -C "$build_dir"
          '';
        };

        build-alive-pkg = pkgs.writeShellApplication {
          name = "build-alive";
          runtimeInputs = with pkgs; [
            cmake
            ninja
            z3
            re2c
            zlib
          ];
          text = ''
            #!/usr/bin/env bash
            set -euo pipefail

            usage() {
              echo "Usage:"
              echo "  build-alive <path_to_alive2> <path_to_llvm_build>"
              echo "  build-alive clean"
              exit 1
            }

            if [ "$#" -eq 1 ] && [ "$1" = "clean" ]; then
              echo "Cleaning Alive2 build directory"
              rm -rf build/alive
              exit 0
            fi

            if [ "$#" -ne 2 ]; then
              usage
            fi

            alive_src="$(realpath "$1")"
            llvm_build="$(realpath "$2")"
            build_dir="$(realpath ./build/alive)"

            if [ ! -d "$alive_src" ]; then
              echo "Error: Alive2 source directory not found"
              exit 1
            fi

            if [ ! -f "$llvm_build/lib/cmake/llvm/LLVMConfig.cmake" ] \
               && [ ! -f "$llvm_build/LLVMConfig.cmake" ]; then
              echo "Error: $llvm_build does not look like an LLVM build or install"
              exit 1
            fi

            mkdir -p "$build_dir"

            cmakeFlags=(
                -GNinja
                -DCMAKE_BUILD_TYPE=Debug
                -DCMAKE_PREFIX_PATH="$llvm_build"
                -DBUILD_TV=1
            )

            if [ ! -f "$build_dir/build.ninja" ]; then
              echo "Configuring Alive2"
              cmake -S "$alive_src" -B "$build_dir" "''${cmakeFlags[@]}"
            else
              echo "Alive2 already configured - skipping CMake"
            fi

            echo "Building Alive2"
            ninja -C "$build_dir"
          '';
        };
        build-all-pkg = pkgs.writeShellApplication {
          name = "build-all";
          runtimeInputs = [
            build-llvm-pkg
            build-alive-pkg
          ];
          text = ''
            #!/usr/bin/env bash
            set -euo pipefail

            usage() {
              echo "Usage:"
              echo "  build-all <path_to_llvm_project> <path_to_alive2>"
              echo "  build-all clean"
              exit 1
            }

            if [ "$#" -eq 1 ] && [ "$1" = "clean" ]; then
              echo "Cleaning LLVM and Alive2 builds"
              build-llvm clean
              build-alive clean
              exit 0
            fi

            if [ "$#" -ne 2 ]; then
              usage
            fi

            llvm_src="$1"
            alive_src="$2"

            echo "=== Building LLVM ==="
            build-llvm "$llvm_src"

            echo
            echo "=== Building Alive2 ==="
            build-alive "$alive_src" build/llvm
          '';
        };
      in
      with pkgs;
      {
        packages.build-llvm = build-llvm-pkg;
        packages.build-alive = build-alive-pkg;
        packages.build-all = build-all-pkg;

        apps.build-llvm = {
          type = "app";
          program = "${self.packages.${system}.build-llvm}/bin/build-llvm";
        };
        apps.build-alive = {
          type = "app";
          program = "${self.packages.${system}.build-alive}/bin/build-alive";
        };
        apps.build-all = {
          type = "app";
          program = "${self.packages.${system}.build-all}/bin/build-all";
        };

        devShells.default = mkShell {
          packages = [
            build-llvm-pkg
            build-alive-pkg
            build-all-pkg
          ];
          shellHook = ''
            export PATH=$PWD/build/llvm/bin:$PATH
            export PATH=$PWD/build/alive:$PATH
          '';
        };
      }
    );
}
