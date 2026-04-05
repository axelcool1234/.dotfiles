#!/usr/bin/env bash
set -euo pipefail

# This script is the "native image work" half of the plugin.
#
# QML coordinates user interaction and state transitions, while this script does
# the compositor-facing and file-facing work:
# - `grim` captures outputs or regions
# - `magick` crops a frozen full-output frame into the final region PNG
# - `wl-copy` mirrors the finished image into the clipboard when available

mode="${1:-region}"
screenshot_dir="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
timestamp="$(date +%Y-%m-%d_%H-%M-%S)"
output_path="$screenshot_dir/Screenshot_${timestamp}.png"

mkdir -p "$screenshot_dir"

copy_to_clipboard() {
  local source_path="$1"

  # Clipboard export is a convenience, not part of correctness. Saving the file
  # should still succeed even if wl-copy is missing or fails.
  if ! command -v wl-copy >/dev/null 2>&1; then
    return 0
  fi

  wl-copy --type image/png < "$source_path" || true
}

normalize_path() {
  local value="$1"

  # Quickshell may hand us file URLs while shell tools expect plain paths.
  case "$value" in
    file://*)
      printf '%s\n' "${value#file://}"
      ;;
    *)
      printf '%s\n' "$value"
      ;;
  esac
}

scale_coord() {
  local value="$1"
  local scale="$2"

  # The selection overlay operates in logical coordinates. The frozen image lives
  # in pixel coordinates, so crop values need to be scaled and rounded.
  awk -v value="$value" -v scale="$scale" 'BEGIN {
    scaled = value * scale
    if (scaled < 0) {
      scaled = 0
    }
    printf "%d", int(scaled + 0.5)
  }'
}

case "$mode" in
  region)
    # Direct region capture. This mode is simple and mostly useful for debugging;
    # the plugin's normal interactive flow uses `freeze` + `region-frozen`.
    geometry="${2:-}"
    if [ -z "$geometry" ]; then
      echo "missing region geometry" >&2
      exit 2
    fi
    grim -g "$geometry" "$output_path"
    copy_to_clipboard "$output_path"
    ;;
  freeze)
    # Capture a full output to a temporary PNG. The overlay renders this file so
    # the selection UI stays stable even while the real screen contents change.
    screen_name="${2:-}"
    requested_path="$(normalize_path "${3:-}")"
    runtime_dir="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}"

    if [ -z "$screen_name" ]; then
      echo "missing screen name" >&2
      exit 2
    fi

    if [ -n "$requested_path" ]; then
      freeze_path="$requested_path"
      mkdir -p "$(dirname "$freeze_path")"
      rm -f "$freeze_path"
    else
      freeze_path="$(mktemp "$runtime_dir/rope-screenshot-freeze.XXXXXX.png")"
    fi

    if ! grim -l 0 -o "$screen_name" "$freeze_path"; then
      rm -f "$freeze_path"
      exit 1
    fi

    if [ -z "$requested_path" ]; then
      printf '%s\n' "$freeze_path"
    fi
    ;;
  region-frozen)
    # Crop a rectangle out of the previously frozen full-output frame.
    frozen_path="$(normalize_path "${2:-}")"
    geometry="${3:-}"
    scale_x="${4:-1}"
    scale_y="${5:-$scale_x}"

    if [ -z "$frozen_path" ] || [ ! -f "$frozen_path" ]; then
      echo "missing frozen frame" >&2
      exit 2
    fi

    if [ -z "$geometry" ]; then
      echo "missing region geometry" >&2
      rm -f "$frozen_path"
      exit 2
    fi

    trap 'rm -f "$frozen_path"' EXIT

    # The geometry arrives in grim/slurp format: "x,y widthxheight".
    position="${geometry%% *}"
    size="${geometry#* }"
    x="${position%%,*}"
    y="${position#*,}"
    width="${size%%x*}"
    height="${size#*x}"

    crop_x="$(scale_coord "$x" "$scale_x")"
    crop_y="$(scale_coord "$y" "$scale_y")"
    crop_width="$(scale_coord "$width" "$scale_x")"
    crop_height="$(scale_coord "$height" "$scale_y")"

    if [ "$crop_width" -lt 1 ] || [ "$crop_height" -lt 1 ]; then
      rm -f "$frozen_path"
      echo "invalid cropped region" >&2
      exit 2
    fi

    magick "$frozen_path" \
      -crop "${crop_width}x${crop_height}+${crop_x}+${crop_y}" \
      +repage \
      "$output_path"

    copy_to_clipboard "$output_path"

    trap - EXIT
    rm -f "$frozen_path"
    ;;
  cleanup)
    # Best-effort temp-file removal used by the controller on every exit path.
    frozen_path="$(normalize_path "${2:-}")"
    if [ -n "$frozen_path" ]; then
      rm -f "$frozen_path"
    fi
    ;;
  screen|fullscreen|output)
    # Full-output capture saves first, then mirrors to the clipboard.
    grim "$output_path"
    copy_to_clipboard "$output_path"
    ;;
  *)
    echo "unsupported mode: $mode" >&2
    exit 2
    ;;
esac
