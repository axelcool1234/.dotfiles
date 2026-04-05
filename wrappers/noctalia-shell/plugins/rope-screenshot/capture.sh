#!/usr/bin/env bash
set -euo pipefail

mode="${1:-region}"
screenshot_dir="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
timestamp="$(date +%Y-%m-%d_%H-%M-%S)"
output_path="$screenshot_dir/Screenshot_${timestamp}.png"

mkdir -p "$screenshot_dir"

normalize_path() {
  local value="$1"

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
    geometry="${2:-}"
    if [ -z "$geometry" ]; then
      echo "missing region geometry" >&2
      exit 2
    fi
    grim -g "$geometry" - | tee "$output_path" | wl-copy --type image/png
    ;;
  freeze)
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
      png:- | tee "$output_path" | wl-copy --type image/png

    trap - EXIT
    rm -f "$frozen_path"
    ;;
  cleanup)
    frozen_path="$(normalize_path "${2:-}")"
    if [ -n "$frozen_path" ]; then
      rm -f "$frozen_path"
    fi
    ;;
  screen|fullscreen|output)
    grim - | tee "$output_path" | wl-copy --type image/png
    ;;
  *)
    echo "unsupported mode: $mode" >&2
    exit 2
    ;;
esac
