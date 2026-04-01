{
  self,
  pkgs,
  ...
}:
let
  vmDrv = self.nixosConfigurations.vm.config.system.build.vm;
in
pkgs.writeShellApplication {
  name = "vm";

  runtimeInputs = [
    pkgs.gum
  ];

  text = /* bash */ ''
    default_ram="2048"
    default_cpu_cores="2"
    default_disk="./vm.qcow2"
    default_backend="x11"
    default_audio_backend="pipewire"
    default_audio_streams="1"
    prompt_input_width="48"

    inherited_gdk_backend="''${GDK_BACKEND-}"
    inherited_gdk_backend_is_set=0
    if [ "''${GDK_BACKEND+x}" = "x" ]; then
      inherited_gdk_backend_is_set=1
    fi

    ram="''${VM_RAM_MB:-}"
    cpu_cores="''${VM_CPU_CORES:-}"
    cpu_sockets="''${VM_CPU_SOCKETS:-}"
    cpu_cores_per_socket="''${VM_CPU_CORES_PER_SOCKET:-}"
    cpu_threads="''${VM_CPU_THREADS:-}"
    disk_image="''${NIX_DISK_IMAGE:-}"
    backend="''${VM_BACKEND:-}"
    if [ -z "$backend" ]; then
      if [ "$inherited_gdk_backend_is_set" -eq 1 ]; then
        backend="inherit-env"
      else
        backend="$default_backend"
      fi
    fi
    audio_backend="''${VM_AUDIO_BACKEND:-$default_audio_backend}"
    audio_streams="''${VM_AUDIO_STREAMS:-$default_audio_streams}"

    have_kvm=0
    kvm_reason=""
    force_interactive=""
    forward_args=()

    show_help() {
      cat <<'EOF'
Usage: vm [options] [-- <extra qemu args>]

Options:
  -h, --help                  Show this help
  --interactive               Force interactive prompts
  --non-interactive           Disable interactive prompts
  --ram <mb>                  RAM in MB
  --cores <n>                 Total vCPU count
  --topology <SxCxT>          CPU topology (sockets x cores x threads)
  --sockets <n>               CPU sockets for topology
  --cores-per-socket <n>      CPU cores per socket for topology
  --threads <n>               CPU threads per core for topology
  --disk <path>               Disk image path
  --backend <x11|wayland|inherit-env>
  --audio-backend <pipewire|pulseaudio|alsa|sdl|none>
  --audio-streams <1|2>

Notes:
  CPU topology is opt-in (no prompt by default). Set it via CLI flags or env:
  VM_CPU_SOCKETS, VM_CPU_CORES_PER_SOCKET, VM_CPU_THREADS.
  Extra QEMU args must come after `--`.
  Set VM_BACKEND to preselect the wrapper backend. Existing GDK_BACKEND is only
  used when backend is set to inherit-env.

Examples:
  vm
  vm --non-interactive --ram 4096 --cores 6
  vm --cores 8 --topology 1x4x2
  vm --sockets 1 --cores-per-socket 4 --threads 2
  vm -- --display sdl
EOF
    }

    parse_topology() {
      topology_raw="$1"
      topology_norm=$(printf '%s' "$topology_raw" | tr 'X,:' 'x')
      IFS='x' read -r topo_s topo_c topo_t extra <<< "$topology_norm"

      if [ -z "$topo_s" ] || [ -z "$topo_c" ] || [ -z "$topo_t" ] || [ -n "$extra" ]; then
        printf 'Invalid --topology value: %s (expected SxCxT, e.g. 1x4x2)\n' "$topology_raw" >&2
        exit 1
      fi

      cpu_sockets="$topo_s"
      cpu_cores_per_socket="$topo_c"
      cpu_threads="$topo_t"
    }

    positive_int_or_die() {
      value="$1"
      name="$2"
      case "$value" in
        *[!0-9]*|"")
          printf '%s must be a positive integer, got: %s\n' "$name" "$value" >&2
          exit 1
          ;;
        0)
          printf '%s must be greater than 0\n' "$name" >&2
          exit 1
          ;;
      esac
    }

    parse_cli_args() {
      while [ "$#" -gt 0 ]; do
        case "$1" in
          -h|--help)
            show_help
            exit 0
            ;;
          --interactive)
            force_interactive="1"
            ;;
          --non-interactive)
            force_interactive="0"
            ;;
          --ram)
            shift
            [ "$#" -gt 0 ] || { echo "Missing value for --ram" >&2; exit 1; }
            ram="$1"
            ;;
          --cores)
            shift
            [ "$#" -gt 0 ] || { echo "Missing value for --cores" >&2; exit 1; }
            cpu_cores="$1"
            ;;
          --topology)
            shift
            [ "$#" -gt 0 ] || { echo "Missing value for --topology" >&2; exit 1; }
            parse_topology "$1"
            ;;
          --sockets)
            shift
            [ "$#" -gt 0 ] || { echo "Missing value for --sockets" >&2; exit 1; }
            cpu_sockets="$1"
            ;;
          --cores-per-socket)
            shift
            [ "$#" -gt 0 ] || { echo "Missing value for --cores-per-socket" >&2; exit 1; }
            cpu_cores_per_socket="$1"
            ;;
          --threads)
            shift
            [ "$#" -gt 0 ] || { echo "Missing value for --threads" >&2; exit 1; }
            cpu_threads="$1"
            ;;
          --disk)
            shift
            [ "$#" -gt 0 ] || { echo "Missing value for --disk" >&2; exit 1; }
            disk_image="$1"
            ;;
          --backend)
            shift
            [ "$#" -gt 0 ] || { echo "Missing value for --backend" >&2; exit 1; }
            backend="$1"
            ;;
          --audio-backend)
            shift
            [ "$#" -gt 0 ] || { echo "Missing value for --audio-backend" >&2; exit 1; }
            audio_backend="$1"
            ;;
          --audio-streams)
            shift
            [ "$#" -gt 0 ] || { echo "Missing value for --audio-streams" >&2; exit 1; }
            audio_streams="$1"
            ;;
          --)
            shift
            forward_args+=("$@")
            break
            ;;
          --*)
            printf 'Unknown option: %s\n' "$1" >&2
            printf 'Pass extra QEMU args after --, for example: vm -- --display sdl\n' >&2
            exit 1
            ;;
          *)
            forward_args+=("$1")
            ;;
        esac
        shift
      done
    }

    current_or_default() {
      current_value="$1"
      fallback_value="$2"
      if [ -n "$current_value" ]; then
        printf '%s' "$current_value"
      else
        printf '%s' "$fallback_value"
      fi
    }

    # Always read interactive input from the controlling terminal so prompt
    # widgets don't accidentally consume piped stdin.
    gum_input_tty() {
      gum input "$@" < /dev/tty
    }

    gum_choose_tty() {
      gum choose "$@" < /dev/tty
    }

    gum_confirm_tty() {
      gum confirm "$@" < /dev/tty
    }

    prompt_input_with_default() {
      prompt_label="$1"
      current_value="$2"
      fallback_value="$3"

      gum_input_tty \
        --prompt "$prompt_label" \
        --value "" \
        --width "$prompt_input_width" \
        --show-help=false \
        --placeholder "$(current_or_default "$current_value" "$fallback_value")"
    }

    prompt_ram() {
      ram_input=$(prompt_input_with_default "RAM (MB): " "$ram" "$default_ram")
      if [ -n "$ram_input" ]; then
        ram="$ram_input"
      fi
    }

    prompt_cpu_cores() {
      cpu_input=$(prompt_input_with_default "CPU cores: " "$cpu_cores" "$default_cpu_cores")
      if [ -n "$cpu_input" ]; then
        cpu_cores="$cpu_input"
      fi
    }

    prompt_cpu_topology() {
      sockets_input=$(prompt_input_with_default "CPU sockets (blank=auto): " "$cpu_sockets" "auto")
      if [ -n "$sockets_input" ]; then
        cpu_sockets="$sockets_input"
      fi

      cores_input=$(prompt_input_with_default "Cores/socket (blank=auto): " "$cpu_cores_per_socket" "auto")
      if [ -n "$cores_input" ]; then
        cpu_cores_per_socket="$cores_input"
      fi

      threads_input=$(prompt_input_with_default "Threads/core (blank=auto): " "$cpu_threads" "auto")
      if [ -n "$threads_input" ]; then
        cpu_threads="$threads_input"
      fi
    }

    prompt_disk_image() {
      disk_input=$(prompt_input_with_default "Disk image: " "$disk_image" "$default_disk")
      if [ -n "$disk_input" ]; then
        disk_image="$disk_input"
      fi
    }

    prompt_backend_choice() {
      backend=$(gum_choose_tty \
        --header "GTK backend" \
        --show-help=false \
        --selected "$(current_or_default "$backend" "$default_backend")" \
        x11 \
        wayland \
        inherit-env)
    }

    prompt_audio_backend() {
      audio_backend=$(gum_choose_tty \
        --header "Audio backend" \
        --show-help=false \
        --selected "$(current_or_default "$audio_backend" "$default_audio_backend")" \
        pipewire \
        pulseaudio \
        alsa \
        sdl \
        none)
    }

    prompt_audio_streams() {
      if [ "$audio_backend" != "none" ]; then
        current_streams=$(current_or_default "$audio_streams" "$default_audio_streams")
        capture_choice=$(gum_choose_tty \
          --header "Audio streams" \
          --show-help=false \
          --selected "$( [ "$current_streams" = "2" ] && printf '%s' playback+capture || printf '%s' playback-only )" \
          playback-only \
          playback+capture)
        if [ "$capture_choice" = "playback+capture" ]; then
          audio_streams="2"
        else
          audio_streams="1"
        fi
      fi
    }

    maybe_reset_existing_disk() {
      effective_disk=$(current_or_default "$disk_image" "$default_disk")
      if [ -e "$effective_disk" ]; then
        if gum_confirm_tty --default=false "Reset existing disk image at $effective_disk?"; then
          rm -f "$effective_disk"
        fi
      fi
    }

    run_prompt_step() {
      case "$1" in
        ram)
          prompt_ram
          ;;
        cpu_cores)
          prompt_cpu_cores
          ;;
        cpu_topology)
          prompt_cpu_topology
          ;;
        disk_image)
          prompt_disk_image
          ;;
        backend)
          prompt_backend_choice
          ;;
        audio_backend)
          prompt_audio_backend
          ;;
        audio_streams)
          prompt_audio_streams
          ;;
        reset_disk)
          maybe_reset_existing_disk
          ;;
        *)
          printf 'Unknown VM prompt step: %s\n' "$1" >&2
          exit 1
          ;;
      esac
    }

    run_prompt_sequence() {
      # Reorder this newline-delimited list to change the prompt flow.
      # Supported IDs: ram, cpu_cores, disk_image, backend, audio_backend,
      # audio_streams, reset_disk, cpu_topology.
      prompt_steps=$(cat <<'EOF'
ram
cpu_cores
disk_image
backend
audio_backend
audio_streams
reset_disk
EOF
)

      mapfile -t prompt_step_list <<< "$prompt_steps"
      for step in "''${prompt_step_list[@]}"; do
        [ -z "$step" ] && continue
        run_prompt_step "$step"
      done
    }

    should_prompt_interactively() {
      if [ "$force_interactive" = "1" ]; then
        return 0
      fi
      if [ "$force_interactive" = "0" ]; then
        return 1
      fi
      [ -t 0 ] && [ -t 1 ]
    }

    apply_defaults() {
      ram="''${ram:-$default_ram}"
      cpu_cores="''${cpu_cores:-$default_cpu_cores}"
      disk_image="''${disk_image:-$default_disk}"
      backend="''${backend:-$default_backend}"
      audio_backend="''${audio_backend:-$default_audio_backend}"
      audio_streams="''${audio_streams:-$default_audio_streams}"
    }

    validate_inputs() {
      positive_int_or_die "$ram" "RAM (MB)"
      positive_int_or_die "$cpu_cores" "CPU cores"

      if [ -n "$cpu_sockets" ]; then
        positive_int_or_die "$cpu_sockets" "CPU sockets"
      fi
      if [ -n "$cpu_cores_per_socket" ]; then
        positive_int_or_die "$cpu_cores_per_socket" "CPU cores per socket"
      fi
      if [ -n "$cpu_threads" ]; then
        positive_int_or_die "$cpu_threads" "CPU threads per core"
      fi

      case "$backend" in
        x11|wayland|inherit-env) ;;
        *)
          printf 'Unsupported backend: %s\n' "$backend" >&2
          exit 1
          ;;
      esac

      case "$audio_streams" in
        1|2) ;;
        *)
          printf 'Audio streams must be 1 or 2, got: %s\n' "$audio_streams" >&2
          exit 1
          ;;
      esac
    }

    build_smp_arg() {
      smp_arg="$cpu_cores"
      if [ -n "$cpu_sockets" ] || [ -n "$cpu_cores_per_socket" ] || [ -n "$cpu_threads" ]; then
        sockets="''${cpu_sockets:-1}"
        cores_per_socket="''${cpu_cores_per_socket:-$cpu_cores}"
        threads="''${cpu_threads:-1}"
        total=$((sockets * cores_per_socket * threads))
        if [ "$total" -ne "$cpu_cores" ]; then
          printf 'CPU topology mismatch: cores=%s but sockets*cores-per-socket*threads=%s\n' "$cpu_cores" "$total" >&2
          exit 1
        fi
        smp_arg="cpus=$cpu_cores,sockets=$sockets,cores=$cores_per_socket,threads=$threads"
      fi
    }

    warn_resource_pressure() {
      host_cores=""
      if command -v getconf >/dev/null 2>&1; then
        host_cores=$(getconf _NPROCESSORS_ONLN 2>/dev/null || true)
      fi

      if [ -n "$host_cores" ] && [ "$cpu_cores" -gt "$host_cores" ]; then
        printf 'Warning: requested CPU cores (%s) exceed host online cores (%s).\n' "$cpu_cores" "$host_cores" >&2
      fi

      host_mem_kb=""
      if [ -r /proc/meminfo ]; then
        while read -r key value _; do
          if [ "$key" = "MemTotal:" ]; then
            host_mem_kb="$value"
            break
          fi
        done < /proc/meminfo
      fi

      if [ -n "$host_mem_kb" ]; then
        host_mem_mb=$((host_mem_kb / 1024))
        if [ "$ram" -gt "$host_mem_mb" ]; then
          printf 'Warning: requested RAM (%s MB) exceeds host memory (%s MB).\n' "$ram" "$host_mem_mb" >&2
        fi
      fi
    }

    configure_audio_qemu_opts() {
      if [ "$audio_backend" = "none" ]; then
        return
      fi

      case "$audio_backend" in
        pipewire)
          audio_driver="pipewire"
          ;;
        pulseaudio)
          audio_driver="pa"
          ;;
        alsa)
          audio_driver="alsa"
          ;;
        sdl)
          audio_driver="sdl"
          ;;
        *)
          printf 'Unsupported audio backend: %s\n' "$audio_backend" >&2
          exit 1
          ;;
      esac

      audio_opts="-audiodev $audio_driver,id=vm-audio -device virtio-sound-pci,audiodev=vm-audio,streams=$audio_streams"
      if [ -n "''${QEMU_OPTS:-}" ]; then
        export QEMU_OPTS="$QEMU_OPTS $audio_opts"
      else
        export QEMU_OPTS="$audio_opts"
      fi
    }

    warn_if_kvm_unavailable() {
      if [ "$have_kvm" -eq 1 ]; then
        return
      fi

      kvm_warning="Warning: KVM acceleration is unavailable ($kvm_reason). The VM will likely fall back to TCG and be very slow."
      if [ "$1" = "1" ]; then
        gum style --foreground 214 "$kvm_warning"
      else
        printf '%s\n' "$kvm_warning" >&2
      fi
    }

    if [ -e /dev/kvm ]; then
      if [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
        have_kvm=1
      else
        kvm_reason="/dev/kvm exists but is not accessible by your user"
      fi
    else
      kvm_reason="/dev/kvm is missing"
    fi

    parse_cli_args "$@"

    interactive_mode=0
    if should_prompt_interactively; then
      interactive_mode=1
    fi

    warn_if_kvm_unavailable "$interactive_mode"

    # Interactive mode is terminal-first by default, with flags to force behavior.
    if [ "$interactive_mode" -eq 1 ]; then
      run_prompt_sequence
    fi

    apply_defaults

    validate_inputs
    build_smp_arg
    warn_resource_pressure
    configure_audio_qemu_opts
    if [ -n "$disk_image" ]; then
      export NIX_DISK_IMAGE="$disk_image"
    fi

    if [ "$backend" = "inherit-env" ]; then
      if [ "$inherited_gdk_backend_is_set" -eq 1 ]; then
        export GDK_BACKEND="$inherited_gdk_backend"
      else
        unset GDK_BACKEND
      fi
    else
      export GDK_BACKEND="$backend"
    fi

    if [ -n "$ram" ]; then
      exec ${vmDrv}/bin/run-vm-vm -m "$ram" -smp "$smp_arg" "''${forward_args[@]}"
    else
      exec ${vmDrv}/bin/run-vm-vm -smp "$smp_arg" "''${forward_args[@]}"
    fi
  '';
}
