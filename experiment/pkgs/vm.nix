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
    default_ram="1024"
    default_disk="./vm.qcow2"
    default_backend="x11"
    default_audio_backend="pipewire"
    default_audio_streams="1"

    ram="''${VM_RAM_MB:-}"
    disk_image="''${NIX_DISK_IMAGE:-}"
    backend="''${GDK_BACKEND:-$default_backend}"
    audio_backend="''${VM_AUDIO_BACKEND:-$default_audio_backend}"
    audio_streams="''${VM_AUDIO_STREAMS:-$default_audio_streams}"

    have_kvm=0
    kvm_reason=""

    if [ -e /dev/kvm ]; then
      if [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
        have_kvm=1
      else
        kvm_reason="/dev/kvm exists but is not accessible by your user"
      fi
    else
      kvm_reason="/dev/kvm is missing"
    fi

    # Only run in a terminal. Scripts calling this program will skip this block.
    if [ -t 0 ] && [ -t 1 ]; then
      if [ "$have_kvm" -ne 1 ]; then
        gum style \
          --foreground 214 \
          "Warning: KVM acceleration is unavailable ($kvm_reason). The VM will likely fall back to TCG and be very slow."
      fi

      ram_input=$(gum input --prompt "RAM (MB): " --placeholder "$default_ram" --value "$ram")
      ram="''${ram_input:-}"

      disk_input=$(gum input --prompt "Disk image: " --placeholder "$default_disk" --value "$disk_image")
      disk_image="''${disk_input:-}"

      backend=$(printf '%s\n' x11 wayland inherit-env | gum choose --header "GTK backend" --selected "$backend")

      audio_backend=$(printf '%s\n' pipewire pulseaudio alsa sdl none | gum choose --header "Audio backend" --selected "$audio_backend")

      if [ "$audio_backend" != "none" ]; then
        capture_choice=$(printf '%s\n' playback-only playback+capture | gum choose --header "Audio streams" --selected "$( [ "$audio_streams" = "2" ] && printf '%s' playback+capture || printf '%s' playback-only )")
        if [ "$capture_choice" = "playback+capture" ]; then
          audio_streams="2"
        else
          audio_streams="1"
        fi
      fi

      effective_disk="''${disk_image:-$default_disk}"
      if [ -e "$effective_disk" ]; then
        if gum confirm --default=false "Reset existing disk image at $effective_disk?"; then
          rm -f "$effective_disk"
        fi
      fi
    fi

    if [ -n "$disk_image" ]; then
      export NIX_DISK_IMAGE="$disk_image"
    fi

    if [ "$backend" = "inherit-env" ]; then
      unset GDK_BACKEND
    else
      export GDK_BACKEND="$backend"
    fi

    if [ "$audio_backend" != "none" ]; then
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
    fi

    if [ -n "$ram" ]; then
      exec ${vmDrv}/bin/run-vm-vm -m "$ram" "$@"
    else
      exec ${vmDrv}/bin/run-vm-vm "$@"
    fi
  '';
}
