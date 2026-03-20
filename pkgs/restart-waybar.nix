{ writeShellApplication, procps, systemd, waybar }:

writeShellApplication {
  name = "restart-waybar";
  runtimeInputs = [
    procps
    systemd
    waybar
  ];

  text = ''
    waybar_is_running() {
      pgrep -u "$UID" -x waybar >/dev/null || pgrep -u "$UID" -x .waybar-wrapped >/dev/null
    }

    terminate_waybar() {
      pkill -u "$UID" -x waybar 2>/dev/null || true
      pkill -u "$UID" -x .waybar-wrapped 2>/dev/null || true
    }

    if systemctl --user --quiet is-active waybar.service; then
      exec systemctl --user restart waybar.service
    fi

    terminate_waybar

    for _ in {1..20}; do
      if ! waybar_is_running; then
        break
      fi

      sleep 0.1
    done

    if waybar_is_running; then
      pkill -KILL -u "$UID" -x waybar 2>/dev/null || true
      pkill -KILL -u "$UID" -x .waybar-wrapped 2>/dev/null || true

      for _ in {1..20}; do
        if ! waybar_is_running; then
          break
        fi

        sleep 0.1
      done
    fi

    if waybar_is_running; then
      echo "failed to stop existing Waybar process" >&2
      exit 1
    fi

    waybar >/dev/null 2>&1 &
  '';
}
