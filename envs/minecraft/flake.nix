{
  description = "Minecraft E2E-E Server";

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
        pkgs = import nixpkgs { inherit system; };
        startServer = pkgs.writeShellScriptBin "start-server" ''
          #!/usr/bin/env bash
          set -euo pipefail

          # === Configuration ===
          SERVERSTARTER_VERSION="2.4.0"
          SERVERSTARTER_JAR="serverstarter-''${SERVERSTARTER_VERSION}.jar"
          SERVERSTARTER_URL="https://github.com/EnigmaticaModpacks/ServerStarter/releases/download/v''${SERVERSTARTER_VERSION}/''${SERVERSTARTER_JAR}"

          CLEANROOM_VERSION="0.3.17-alpha"
          CLEANROOM_INSTALLER_JAR="cleanroom-''${CLEANROOM_VERSION}-installer.jar"
          CLEANROOM_INSTALLER_URL="https://github.com/CleanroomMC/Cleanroom/releases/download/''${CLEANROOM_VERSION}/''${CLEANROOM_INSTALLER_JAR}"
          CLEANROOM_SERVER_JAR="cleanroom-''${CLEANROOM_VERSION}.jar"

          SERVER_DIRECTORY="server"

          RAMDISK_SIZE="2G"

          # === Helper functions ===
          run_serverstarter() {
            echo "[INFO] Running ServerStarter for initial setup..."
            PATH="${pkgs.jdk8}/bin:$PATH" java -jar "$SERVERSTARTER_JAR"
          }

          run_cleanroom_installer() {
            echo "[INFO] Running Cleanroom installer..."
            PATH="${pkgs.jdk8}/bin:$PATH" java -jar "$CLEANROOM_INSTALLER_JAR" --installServer
          }

          run_cleanroom_server() {
            echo "[INFO] Starting Cleanroom server..."
            PATH="${pkgs.jdk25}/bin:$PATH" java -jar "$CLEANROOM_SERVER_JAR"
          }

          setup_ramdisk() {
            local SAVE_DIR
            SAVE_DIR=$(grep '^level-name' server.properties | awk -F'=' '{print $2}')
            if grep -q 'ramDisk:\s*yes' server-setup-config.yaml; then
              echo "[INFO] Setting up RAM disk for world '$SAVE_DIR'"
              mv "$SAVE_DIR" "''${SAVE_DIR}_backup"
              mkdir -p "$SAVE_DIR"
              sudo mount -t tmpfs -o size="$RAMDISK_SIZE" tmpfs "$SAVE_DIR"
              echo "$SAVE_DIR"
            else
              echo ""
            fi
          }

          teardown_ramdisk() {
            local SAVE_DIR=$1
            if [[ -n "$SAVE_DIR" ]]; then
              echo "[INFO] Cleaning up RAM disk for world '$SAVE_DIR'"
              sudo umount "$SAVE_DIR"
              rm -rf "$SAVE_DIR"
              mv "''${SAVE_DIR}_backup" "$SAVE_DIR"
            fi
          }

          # === Main logic ===
          # Step 0: Move to the server directory
          cd $SERVER_DIRECTORY

          # Step 1: ensure ServerStarter jar exists
          if [[ ! -f "$SERVERSTARTER_JAR" ]]; then
            echo "[INFO] Downloading ServerStarter..."
            if command -v wget >/dev/null; then
              wget -O "$SERVERSTARTER_JAR" "$SERVERSTARTER_URL"
            elif command -v curl >/dev/null; then
              curl -L -o "$SERVERSTARTER_JAR" "$SERVERSTARTER_URL"
            else
              echo "[ERROR] Please install wget or curl." >&2
              exit 1
            fi
          fi

          # Step 1.5: ensure Cleanroom installer jar exists
          if [[ ! -f "$CLEANROOM_INSTALLER_JAR" ]]; then
            echo "[INFO] Downloading Cleanroom installer..."
            if command -v wget >/dev/null; then
              wget -O "$CLEANROOM_INSTALLER_JAR" "$CLEANROOM_INSTALLER_URL"
            elif command -v curl >/dev/null; then
              curl -L -o "$CLEANROOM_INSTALLER_JAR" "$CLEANROOM_INSTALLER_URL"
            else
              echo "[ERROR] Please install wget or curl." >&2
              exit 1
            fi
          fi

          # Step 2: setup optional RAM disk
          SAVE_DIR=$(setup_ramdisk || true)

          # Step 3: check which stage we are in
          if [[ ! -f "$CLEANROOM_SERVER_JAR" ]]; then
            # Cleanroom server not yet installed
            echo "[INFO] Running initial setup (server starter; then after it's done via manual shutdown, cleanroom)..."
            run_serverstarter
            echo "[INFO] Installing Cleanroom..."
            run_cleanroom_installer
          else
            # Cleanroom already installed
            run_cleanroom_server
          fi

          # Step 4: teardown RAM disk if used
          teardown_ramdisk "$SAVE_DIR"
        '';
      in
      {
        devShells.default = pkgs.mkShell {
          packages = [
            pkgs.jdk25
            pkgs.jdk8
            pkgs.wget
            pkgs.curl
            pkgs.gawk
          ];
        };
        # Expose script as a standalone flake app
        packages.default = startServer;
        apps.default = flake-utils.lib.mkApp { drv = startServer; };
      }
    );
}
