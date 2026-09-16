{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "android-control";

  runtimeInputs = [
    pkgs.android-tools
    pkgs.scrcpy
  ];

  text = /* bash */ ''
    set -u

    show_help() {
      cat <<'EOF'
Usage: android-control [scrcpy options]

Try to mirror and control an Android device with scrcpy. If mirroring fails
(for example, because USB debugging has not been authorized), open scrcpy's
OTG mouse/keyboard mode instead. Close the OTG window after approving USB
debugging on the device; android-control will then retry mirroring.

Any options are passed to mirrored scrcpy sessions. OTG mode is always started
without additional options.
EOF
    }

    case "''${1-}" in
      -h|--help)
        show_help
        exit 0
        ;;
    esac

    trap 'exit 130' INT
    trap 'exit 143' TERM

    while true; do
      printf '%s\n' "Trying Android screen mirroring..." >&2

      if scrcpy "$@"; then
        exit 0
      else
        mirror_status=$?
      fi

      printf \
        'Mirroring failed (exit %s). Starting temporary OTG control...\n' \
        "$mirror_status" >&2
      printf '%s\n' \
        "Approve USB debugging on the device, then close the OTG window to retry mirroring." \
        >&2

      if scrcpy --otg; then
        printf '%s\n' "OTG control closed; retrying mirroring..." >&2
      else
        otg_status=$?
        printf 'OTG control failed (exit %s).\n' "$otg_status" >&2
        exit "$otg_status"
      fi
    done
  '';
}
