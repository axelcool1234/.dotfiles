#!/usr/bin/env bash
set -euo pipefail

mode="${1:-region}"
geometry="${2:-}"
screenshot_dir="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
timestamp="$(date +%Y-%m-%d_%H-%M-%S)"
output_path="$screenshot_dir/Screenshot_${timestamp}.png"

mkdir -p "$screenshot_dir"

case "$mode" in
  region)
    if [ -z "$geometry" ]; then
      echo "missing region geometry" >&2
      exit 2
    fi
    grim -g "$geometry" - | tee "$output_path" | wl-copy --type image/png
    ;;
  screen|fullscreen|output)
    grim - | tee "$output_path" | wl-copy --type image/png
    ;;
  *)
    echo "unsupported mode: $mode" >&2
    exit 2
    ;;
esac
