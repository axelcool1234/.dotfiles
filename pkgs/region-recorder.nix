{
  pkgs,
  selfPkgs,
  ...
}:
pkgs.writeShellApplication {
  name = "region-recorder";

  runtimeInputs = [
    pkgs.gawk         # Parse Pulse source listings and split helper output lines.
    pkgs.coreutils    # File ops, timestamps, sleeps, and directory lifecycle.
    pkgs.ffmpeg       # GIF conversion plus mixed-audio capture and final mux.
    pkgs.gnugrep      # Exact-match monitor-source checks during device lookup.
    pkgs.pulseaudio   # `pactl` for discovering the active sink/source devices.
    pkgs.procps       # `pgrep`/`pkill` for active-recorder detection and stop.
    pkgs.python3      # Small helpers for JSON escaping and file:// URI building.
    pkgs.slurp        # Interactive Wayland region selection before recording.
    pkgs.wl-clipboard # `wl-copy` for copying the saved output URI.
    pkgs.wl-screenrec # Actual Wayland screen recorder for region video capture.
    selfPkgs.noctalia-shell # Noctalia IPC entrypoint for toast notifications.
  ];

  text = /* bash */ ''
    # region-recorder: Niri/Noctalia region recording helper for Wayland.
    #
    # Overview:
    # - This command is designed for `niri` keybinds that behave like a toggle.
    # - A `toggle` invocation either starts a new region recording or stops the
    #   current one, depending on whether the recorder is already active.
    # - Video mode records the selected region with `wl-screenrec` and, when
    #   audio is enabled, captures desktop output plus microphone input through
    #   one live `ffmpeg` audio graph so both sources stay in sync.
    # - GIF mode records to a temporary video first and converts after stop.
    # - Final outputs are timestamped, copied to the clipboard as `file://`
    #   URIs by default, and announced through Noctalia toast notifications.
    #
    # Sources / references:
    # - Noctalia toast IPC docs:
    #   https://docs.noctalia.dev/getting-started/keybinds/interface-and-plugins/#toast-notifications
    # - wl-screenrec upstream project / usage reference:
    #   https://github.com/russelltg/wl-screenrec
    # - wl-clipboard upstream project / URI clipboard behavior:
    #   https://github.com/bugaevc/wl-clipboard
    # - Audio-combination background reference that informed later iterations of this script:
    #   https://github.com/ammen99/wf-recorder/wiki#recording-both-mic-input-and-application-sounds
    # - Prior fish functions from older version of dotfiles:
    #   https://github.com/axelcool1234/.dotfiles/blob/c06febae6b9ca0531d72495e79c2960d81f1b876/home-modules/programs/fish/functions/record_screen_mp4.fish
    #   https://github.com/axelcool1234/.dotfiles/blob/c06febae6b9ca0531d72495e79c2960d81f1b876/home-modules/programs/fish/functions/record_screen_gif.fish
    #
    # Usage:
    #   region-recorder toggle video [--copy uri|off] [--audio on|off]
    #   region-recorder toggle gif   [--copy uri|off]
    #   region-recorder stop
    #   region-recorder status
    #   region-recorder --help
    #
    # Behavior:
    # - When idle, `toggle <mode>` asks you to select a region with `slurp` and
    #   then starts `wl-screenrec` for that region.
    # - When already recording, `toggle <mode>` stops the active recording
    #   regardless of mode.
    # - Video recordings are saved as timestamped `.mp4` files in `~/Videos`.
    # - GIF recordings are captured to a temporary `.mp4`, then converted to a
    #   timestamped `.gif` with conservative defaults that favor pasteability:
    #   15 FPS, max width 1280px, palette-based conversion.
    # - Successful saves copy a `file://` URI to the Wayland clipboard by
    #   default using `text/uri-list` so the result can be pasted into apps that
    #   understand file references.
    # - Noctalia toasts are used for user feedback.
    #
    # Invariants / assumptions:
    # - Only one recording is intended to be active at a time.
    # - Runtime state lives under `XDG_RUNTIME_DIR` and is safe to discard.
    # - `wl-screenrec` owns the video timeline; stop requests only signal it and
    #   then let the original worker finish cleanup/finalization.
    # - Video recordings may have an auxiliary mixed-audio file during capture;
    #   that file must finish cleanly before the final mux step runs.
    # - Source resolution is machine-agnostic: desktop audio comes from the
    #   default sink monitor, microphone audio comes from a non-monitor source.
    #
    # Notes:
    # - Audio is enabled by default for video recordings. Desktop audio from
    #   the default sink monitor and microphone audio from a non-monitor source
    #   are captured by one background ffmpeg process into a single mixed audio
    #   track, then muxed into the final video after recording stops. GIF mode
    #   disables audio because the output format cannot store it.
    # - `wl-screenrec` cannot capture a region spanning multiple displays; if it
    #   exits immediately after selection, retry with a region on a single
    #   display.

    set -eu

    runtime_root="''${XDG_RUNTIME_DIR:-/tmp}"
    state_dir="$runtime_root/region-recorder"
    state_file="$state_dir/active.env"
    lock_dir="$state_dir/lock"
    log_file="$state_dir/record.log"
    videos_dir="''${XDG_VIDEOS_DIR:-$HOME/Videos}"

    default_copy_mode="uri"
    default_audio_mode="on"
    default_gif_fps="15"
    default_gif_max_width="1280"

    # Initialize state-derived variables so ShellCheck understands they exist
    # before `load_state` sources the active session file.
    pid=""
    phase=""
    mode=""
    started_at=""
    geometry=""
    final_path=""
    temp_path=""
    copy_mode=""
    audio_mode=""
    audio_pid=""
    audio_path=""

    mkdir -p "$state_dir" "$videos_dir"

    # Release the short-lived action lock. Safe to call multiple times.
    release_lock() {
      rmdir "$lock_dir" 2>/dev/null || true
    }

    # Acquire a non-inherited lock for short control actions only.
    # Assumption: the lock must not outlive the current shell process.
    acquire_lock() {
      if ! mkdir "$lock_dir" 2>/dev/null; then
        toast_send "warning" "Recorder busy" "Another recorder action is already in progress."
        exit 1
      fi

      trap release_lock EXIT INT TERM
    }

    # Print CLI help text and exit guidance for direct shell use.
    show_help() {
      cat <<'EOF'
Usage:
  region-recorder toggle video [--copy uri|off] [--audio on|off]
  region-recorder toggle gif   [--copy uri|off]
  region-recorder stop
  region-recorder status
  region-recorder --help

Commands:
  toggle   Start region selection and recording if idle, otherwise stop the
           current recording.
  stop     Stop the current recording if one is active.
  status   Print whether a recording is active and the current output path.

Options:
  --copy <uri|off>   Copy a file:// URI for the saved output to the clipboard.
                     Default: uri
  --audio <on|off>   Enable or disable audio capture for video mode.
                     Default: on

Examples:
  region-recorder toggle video
  region-recorder toggle gif --copy uri
  region-recorder stop
EOF
    }

    # JSON-escape a single string for Noctalia IPC payloads.
    # Input: one shell string. Output: one JSON string literal.
    json_string() {
      python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$1"
    }

    # Convert a filesystem path to an absolute file:// URI.
    # Input: path. Output: normalized URI on stdout.
    path_to_uri() {
      python3 -c 'import pathlib,sys; print(pathlib.Path(sys.argv[1]).expanduser().resolve().as_uri())' "$1"
    }

    # Send one Noctalia toast notification.
    # Inputs: type, title, optional body. Falls back to stderr if IPC fails.
    toast_send() {
      toast_type="$1"
      title="$2"
      body="''${3-}"

      icon_json=$(json_string "media-record")
      title_json=$(json_string "$title")
      body_json=$(json_string "$body")
      type_json=$(json_string "$toast_type")
      payload=$(printf '{"title":%s,"body":%s,"type":%s,"icon":%s}' "$title_json" "$body_json" "$type_json" "$icon_json")

      if ! noctalia-shell ipc call toast send "$payload" >/dev/null 2>&1; then
        printf '%s: %s\n' "$title" "$body" >&2
      fi
    }

    # Persist the active session metadata atomically.
    # Inputs: pid, phase, mode, started_at, geometry, final_path, temp_path,
    # copy_mode, audio_mode, audio_pid, audio_path.
    write_state() {
      tmp_state="$state_file.tmp"
      {
        printf 'pid=%q\n' "$1"
        printf 'phase=%q\n' "$2"
        printf 'mode=%q\n' "$3"
        printf 'started_at=%q\n' "$4"
        printf 'geometry=%q\n' "$5"
        printf 'final_path=%q\n' "$6"
        printf 'temp_path=%q\n' "$7"
        printf 'copy_mode=%q\n' "$8"
        printf 'audio_mode=%q\n' "$9"
        printf 'audio_pid=%q\n' "''${10}"
        printf 'audio_path=%q\n' "''${11}"
      } > "$tmp_state"
      mv "$tmp_state" "$state_file"
    }

    # Rewrite the current state file while changing only the lifecycle phase.
    # Input: new phase string. Assumes `load_state` already succeeds.
    update_phase() {
      new_phase="$1"
      if ! load_state; then
        return 1
      fi

      # Re-write the active session file while only changing the lifecycle phase.
      write_state \
        "$pid" \
        "$new_phase" \
        "$mode" \
        "$started_at" \
        "$geometry" \
        "$final_path" \
        "$temp_path" \
        "$copy_mode" \
        "$audio_mode" \
        "$audio_pid" \
        "$audio_path"
    }

    # Load the active session file into the current shell.
    # Output: sets global state variables when the file exists.
    load_state() {
      if [ ! -f "$state_file" ]; then
        return 1
      fi

      # shellcheck disable=SC1090
      . "$state_file"
    }

    # Delete the current active-session state file.
    clear_state() {
      rm -f "$state_file"
    }

    # Convenience wrapper for rewriting state with the currently loaded values.
    write_current_state() {
      write_state \
        "$pid" \
        "$phase" \
        "$mode" \
        "$started_at" \
        "$geometry" \
        "$final_path" \
        "$temp_path" \
        "$copy_mode" \
        "$audio_mode" \
        "$audio_pid" \
        "$audio_path"
    }

    # Decide whether the recorder should be considered active.
    # Invariant: a `finalizing` phase still counts as active so a new toggle
    # does not start another recording while cleanup is still running.
    recording_active() {
      if ! load_state; then
        return 1
      fi

      if [ "''${phase-}" = "finalizing" ]; then
        return 0
      fi

      if pgrep -x wl-screenrec >/dev/null 2>&1; then
        return 0
      fi

      # The worker can switch the state to `finalizing` after the first read,
      # so re-load once before deciding this session is truly inactive.
      if load_state && [ "''${phase-}" = "finalizing" ]; then
        return 0
      fi

      clear_state
      return 1
    }

    # Copy the saved output location as a file:// URI to the Wayland clipboard.
    # Input: saved path. Output: URI on stdout for toast text.
    clipboard_copy_uri() {
      saved_path="$1"
      uri=$(path_to_uri "$saved_path")
      printf '%s\r\n' "$uri" | wl-copy --type text/uri-list
      printf '%s' "$uri"
    }

    # Resolve the desktop-audio source from the current default sink monitor.
    # Output: Pulse source name on stdout, or non-zero if unavailable.
    resolve_desktop_audio_device() {
      if ! command -v pactl >/dev/null 2>&1; then
        return 1
      fi

      if [ -n "''${REGION_RECORDER_DESKTOP_SOURCE-}" ]; then
        printf '%s' "$REGION_RECORDER_DESKTOP_SOURCE"
        return 0
      fi

      default_sink=$(pactl get-default-sink 2>/dev/null || true)
      if [ -z "$default_sink" ]; then
        return 1
      fi

      monitor_source="$default_sink.monitor"
      if pactl list short sources 2>/dev/null | awk '{ print $2 }' | grep -Fx "$monitor_source" >/dev/null 2>&1; then
        printf '%s' "$monitor_source"
        return 0
      fi

      return 1
    }

    # Resolve a microphone-like Pulse source.
    # Prefers the default source when it is not a monitor; otherwise falls back
    # to the first non-monitor source advertised by Pulse/PipeWire.
    resolve_mic_audio_device() {
      if ! command -v pactl >/dev/null 2>&1; then
        return 1
      fi

      if [ -n "''${REGION_RECORDER_MIC_SOURCE-}" ]; then
        printf '%s' "$REGION_RECORDER_MIC_SOURCE"
        return 0
      fi

      default_source=$(pactl get-default-source 2>/dev/null || true)
      if [ -n "$default_source" ] && [ "''${default_source##*.}" != "monitor" ]; then
        printf '%s' "$default_source"
        return 0
      fi

      fallback_source=$(pactl list short sources 2>/dev/null | awk '$2 !~ /\.monitor$/ { print $2; exit }')
      if [ -n "$fallback_source" ]; then
        printf '%s' "$fallback_source"
        return 0
      fi

      return 1
    }

    # Start one background ffmpeg process that produces a single mixed audio
    # track for the whole recording session.
    # Output: two lines on stdout: the ffmpeg PID and the audio file path.
    # Assumption: callers will stop the process with SIGINT and wait for it to
    # finalize before attempting the final mux.
    start_audio_capture() {
      desktop_source="$(resolve_desktop_audio_device || true)"
      mic_source="$(resolve_mic_audio_device || true)"

      if [ -z "$desktop_source" ] && [ -z "$mic_source" ]; then
        return 1
      fi

      audio_path="$state_dir/$started_at.audio.m4a"

      if [ -n "$desktop_source" ] && [ -n "$mic_source" ] && [ "$desktop_source" != "$mic_source" ]; then
        # Keep both live sources in one ffmpeg graph so they share a clock and
        # the final mux step only has to attach one mixed audio track.
        ffmpeg -y \
          -thread_queue_size 512 -f pulse -i "$desktop_source" \
          -thread_queue_size 512 -f pulse -i "$mic_source" \
          -filter_complex '[0:a][1:a]amix=inputs=2:dropout_transition=0:normalize=0,aresample=async=1:first_pts=0[a]' \
          -map '[a]' \
          -c:a aac \
          "$audio_path" >> "$log_file" 2>&1 &
      else
        single_source="$desktop_source"
        if [ -z "$single_source" ]; then
          single_source="$mic_source"
        fi

        ffmpeg -y \
          -thread_queue_size 512 -f pulse -i "$single_source" \
          -c:a aac \
          "$audio_path" >> "$log_file" 2>&1 &
      fi

      printf '%s\n%s' "$!" "$audio_path"
    }

    # Build the ffmpeg filter used for GIF post-processing.
    # Output: one filter_complex string on stdout.
    gif_filter() {
      printf "fps=%s,scale='min(%s,iw)':-2:flags=lanczos,split[s0][s1];[s0]palettegen=stats_mode=diff[p];[s1][p]paletteuse=dither=sierra2_4a" \
        "$default_gif_fps" "$default_gif_max_width"
    }

    # Wait until all wl-screenrec processes have exited, with a short timeout.
    # Used after sending SIGINT to the active recorder.
    wait_for_exit() {
      elapsed=0
      max_wait=300

      while pgrep -x wl-screenrec >/dev/null 2>&1; do
        if [ "$elapsed" -ge "$max_wait" ]; then
          return 1
        fi

        sleep 0.1
        elapsed=$((elapsed + 1))
      done

      return 0
    }

    # Wait for the background audio-capture ffmpeg process to finalize.
    # Input: PID. Returns success if the process exits before timeout.
    wait_for_audio_exit() {
      target_pid="$1"
      elapsed=0
      max_wait=300

      if [ -z "$target_pid" ]; then
        return 0
      fi

      while kill -0 "$target_pid" 2>/dev/null; do
        if [ "$elapsed" -ge "$max_wait" ]; then
          return 1
        fi

        sleep 0.1
        elapsed=$((elapsed + 1))
      done

      return 0
    }

    # Finalize the current recording after capture has stopped.
    # Responsibilities:
    # - mark the session as finalizing
    # - produce the final GIF when needed
    # - wait for mixed-audio finalization and mux it into video mode
    # - copy the resulting URI to the clipboard when enabled
    # - clear runtime state and emit the success toast
    finalize_recording() {
      if ! load_state; then
        return 1
      fi

      update_phase "finalizing"

      output_path="$final_path"
      clipboard_message=""

      if [ "$mode" = "gif" ]; then
        filter_complex=$(gif_filter)
        if ! ffmpeg -y -i "$temp_path" -filter_complex "$filter_complex" "$final_path" >> "$log_file" 2>&1; then
          toast_send "error" "GIF conversion failed" "Temporary video kept at $temp_path"
          return 1
        fi
        rm -f "$temp_path"
      elif [ "$temp_path" != "$final_path" ]; then
        mv "$temp_path" "$final_path"
      fi

      if [ "$mode" = "video" ] && [ -n "$audio_path" ] && [ -s "$audio_path" ]; then
        if ! wait_for_audio_exit "$audio_pid"; then
          toast_send "warning" "Audio finalize timed out" "Saved video without the mixed audio track."
          rm -f "$audio_path"
        else
          muxed_path="$state_dir/$started_at.muxed.mp4"
          if ffmpeg -y -i "$final_path" -i "$audio_path" -map 0:v -map 1:a -c:v copy -c:a copy -shortest "$muxed_path" >> "$log_file" 2>&1; then
            mv "$muxed_path" "$final_path"
          else
            rm -f "$muxed_path"
            toast_send "warning" "Audio mux failed" "Saved video without the mixed audio track."
          fi
          rm -f "$audio_path"
        fi
      fi

      if [ "$copy_mode" = "uri" ]; then
        copied_uri=$(clipboard_copy_uri "$output_path")
        clipboard_message=" Copied $copied_uri to the clipboard."
      fi

      clear_state
      toast_send "success" "Recording saved" "$output_path.$clipboard_message"
    }

    # Long-lived worker that owns the actual capture process.
    # Inputs: mode, audio_mode.
    # Invariant: this is the only place that should run `wl-screenrec`.
    # Stop requests only signal the child process; this worker remains
    # responsible for all post-processing and cleanup afterward.
    record_worker() {
      worker_mode="$1"
      worker_audio_mode="$2"

      if ! load_state; then
        toast_send "error" "Recorder state missing" "Could not load active recording metadata."
        return 1
      fi

      recorder_args=(
        --filename "$temp_path"
        --geometry "$geometry"
      )

      if [ "$worker_mode" = "video" ] && [ "$worker_audio_mode" = "on" ]; then
        audio_result="$(start_audio_capture || true)"
        if [ -n "$audio_result" ]; then
          audio_pid=$(printf '%s' "$audio_result" | awk 'NR == 1 { print; exit }')
          audio_path=$(printf '%s' "$audio_result" | awk 'NR == 2 { print; exit }')
          write_current_state
        else
          toast_send "warning" "Audio unavailable" "Could not resolve desktop or microphone sources; recording video without audio."
        fi
      fi

      : > "$log_file"
      wl-screenrec "''${recorder_args[@]}" >> "$log_file" 2>&1
      finalize_recording
    }

    # Signal the active recording to stop.
    # This function does not finalize outputs directly; it only requests stop
    # and lets the original worker continue into `finalize_recording`.
    stop_recording() {
      if ! recording_active; then
        toast_send "warning" "No recording active" "There is nothing to stop."
        return 1
      fi

      if load_state && [ "''${phase-}" = "finalizing" ]; then
        toast_send "info" "Finalizing recording" "Please wait for the current save to finish."
        return 0
      fi

      toast_send "info" "Stopping recording" "Finalizing $mode capture..."
      if [ -n "$audio_pid" ] && kill -0 "$audio_pid" 2>/dev/null; then
        kill -INT "$audio_pid" || true
      fi
      pkill -INT -x wl-screenrec || true
      return 0
    }

    # Start a new recording session after region selection.
    # Inputs: requested_mode, copy_mode, audio_mode.
    # Side effects: writes runtime state, spawns the background worker, and
    # emits the initial start toast.
    start_recording() {
      requested_mode="$1"
      copy_mode="$2"
      audio_mode="$3"

      if ! geometry=$(slurp 2>/dev/null); then
        exit 0
      fi

      if [ -z "$geometry" ]; then
        exit 0
      fi

      timestamp=$(date '+%F_%H-%M-%S')

      if [ "$requested_mode" = "video" ]; then
        final_path="$videos_dir/$timestamp.mp4"
        temp_path="$final_path"
      else
        final_path="$videos_dir/$timestamp.gif"
        temp_path="$state_dir/$timestamp.mp4"
      fi

      write_state \
        "0" \
        "recording" \
        "$requested_mode" \
        "$timestamp" \
        "$geometry" \
        "$final_path" \
        "$temp_path" \
        "$copy_mode" \
        "$audio_mode" \
        "" \
        ""

      ( record_worker "$requested_mode" "$audio_mode" ) >/dev/null 2>&1 &
      worker_pid=$!

      write_state \
        "$worker_pid" \
        "recording" \
        "$requested_mode" \
        "$timestamp" \
        "$geometry" \
        "$final_path" \
        "$temp_path" \
        "$copy_mode" \
        "$audio_mode" \
        "" \
        ""

      sleep 0.5
      if ! pgrep -x wl-screenrec >/dev/null 2>&1; then
        wait "$worker_pid" || true
        clear_state
        toast_send "error" "Failed to start recording" "Check the selected region and try again."
        return 1
      fi

      if [ "$requested_mode" = "gif" ]; then
        toast_send "info" "GIF recording started" "Region $geometry selected. GIF conversion happens after stop."
      else
        toast_send "info" "Recording started" "Saving to $final_path"
      fi
    }

    # Print the currently loaded runtime state in a shell-friendly format.
    status_recording() {
      if recording_active; then
        printf 'active\n'
        printf 'pid=%s\n' "$pid"
        printf 'phase=%s\n' "$phase"
        printf 'mode=%s\n' "$mode"
        printf 'started_at=%s\n' "$started_at"
        printf 'output=%s\n' "$final_path"
        printf 'geometry=%s\n' "$geometry"
        printf 'audio_pid=%s\n' "$audio_pid"
        printf 'audio_path=%s\n' "$audio_path"
      else
        printf 'inactive\n'
      fi
    }

    command="''${1-}"
    if [ -z "$command" ]; then
      show_help
      exit 1
    fi
    shift || true

    copy_mode="$default_copy_mode"
    audio_mode="$default_audio_mode"

    case "$command" in
      -h|--help|help)
        show_help
        exit 0
        ;;
      status)
        acquire_lock
        status_recording
        exit 0
        ;;
      stop)
        acquire_lock
        stop_recording
        exit 0
        ;;
      __record)
        record_mode="''${1-}"
        record_audio_mode="''${2-}"
        if [ "$record_mode" != "video" ] && [ "$record_mode" != "gif" ]; then
          printf '__record requires a mode of video or gif\n' >&2
          exit 1
        fi
        record_worker "$record_mode" "$record_audio_mode"
        exit 0
        ;;
      toggle)
        requested_mode="''${1-}"
        if [ "$requested_mode" != "video" ] && [ "$requested_mode" != "gif" ]; then
          printf 'toggle requires a mode of video or gif\n' >&2
          exit 1
        fi
        shift || true

        while [ "$#" -gt 0 ]; do
          case "$1" in
            --copy)
              shift
              [ "$#" -gt 0 ] || { echo 'Missing value for --copy' >&2; exit 1; }
              copy_mode="$1"
              ;;
            --audio)
              shift
              [ "$#" -gt 0 ] || { echo 'Missing value for --audio' >&2; exit 1; }
              audio_mode="$1"
              ;;
            -h|--help)
              show_help
              exit 0
              ;;
            *)
              printf 'Unknown option: %s\n' "$1" >&2
              exit 1
              ;;
          esac
          shift || true
        done

        case "$copy_mode" in
          uri|off) ;;
          *)
            printf 'Invalid --copy value: %s\n' "$copy_mode" >&2
            exit 1
            ;;
        esac

        case "$audio_mode" in
          on|off) ;;
          *)
            printf 'Invalid --audio value: %s\n' "$audio_mode" >&2
            exit 1
            ;;
        esac

        acquire_lock

        if recording_active; then
          stop_recording
        else
          if [ "$requested_mode" = "gif" ]; then
            audio_mode="off"
          fi
          start_recording "$requested_mode" "$copy_mode" "$audio_mode"
        fi
        ;;
      *)
        printf 'Unknown command: %s\n' "$command" >&2
        show_help >&2
        exit 1
        ;;
    esac
  '';
}
