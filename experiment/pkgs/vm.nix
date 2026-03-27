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

  text = ''
    default_ram="1024"
    default_disk="./vm.qcow2"
    default_backend="x11"

    ram="''${VM_RAM_MB:-}"
    disk_image="''${NIX_DISK_IMAGE:-}"
    backend="''${GDK_BACKEND:-$default_backend}"

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

    if [ -n "$ram" ]; then
      exec ${vmDrv}/bin/run-vm-vm -m "$ram" "$@"
    else
      exec ${vmDrv}/bin/run-vm-vm "$@"
    fi
  '';
}
