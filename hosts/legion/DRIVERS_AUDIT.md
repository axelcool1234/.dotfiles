# Legion Drivers Audit

Use this guide when you need to re-check whether [`hosts/legion/drivers.nix`](/home/axelcool1234/.dotfiles/hosts/legion/drivers.nix) still matches the real behavior of the `legion` machine.

This guide is intentionally host-specific. It is not a generic NVIDIA or NixOS graphics guide.

## Goal

Determine whether [`hosts/legion/drivers.nix`](/home/axelcool1234/.dotfiles/hosts/legion/drivers.nix) should stay as-is, receive small updates, or be redesigned.

The audit should answer:

- Is the file still correct for this exact machine?
- Do the chosen defaults still match current NixOS and Hyprland guidance closely enough?
- Are any settings now redundant because upstream modules already cover them?
- Has the real hardware behavior changed enough that the encoded policy should change too?

## Host profile

Assume the following unless live inspection proves otherwise:

- Hostname: `legion`
- Vendor: `LENOVO`
- DMI product code: `82RF`
- Board: `LNVNB161216`
- Closest upstream hardware profile: `nixos-hardware.nixosModules.lenovo-legion-16iah7h`
- CPU: Intel Core i7-12700H
- GPU layout: Intel integrated graphics + NVIDIA RTX 3070 Ti Laptop GPU
- Intel GPU bus ID: `PCI:00:02:0`
- NVIDIA GPU bus ID: `PCI:01:00:0`
- Desktop environment: Hyprland on Wayland

Current intended graphics policy:

- Default boot behavior is `Intel-only`
- That default is intended for firmware `hybrid` mode
- A specialisation named `nvidia-only` exists for firmware `dGPU-only` mode
- Hybrid mode with a healthy NVIDIA offload path is *not* currently treated as a supported / trusted mode on this host
- Both supported modes have now been re-validated successfully:
  - default boot + firmware hybrid mode
  - `nvidia-only` boot + firmware dGPU-only mode
- The Legion host also installs:
  - `lenovo-legion` for Legion firmware/platform controls
  - `legion-gpu-mode` as a host-local helper that pairs GPU-mode switching with
    the matching next GRUB entry

Known findings from the current round of investigation:

- Firmware `dGPU-only` mode was able to run Hyprland on NVIDIA
- Firmware `hybrid` mode was able to run Hyprland on Intel
- In firmware `hybrid` mode, the NVIDIA dGPU repeatedly failed adapter initialization across multiple tested configurations
- Errors observed during those failed hybrid-NVIDIA attempts included:
  - `RmInitAdapter failed`
  - `Failed to allocate NvKmsKapiDevice`
  - `nvidia-smi: No devices were found`
- In the validated `nvidia-only` mode, the internal panel initially came up at
  60 Hz despite 165 Hz being available, so the Hyprland config was updated to pin
  the Legion internal panel to `2560x1600@165`.

Do not edit [`hosts/legion/hardware-configuration.nix`](/home/axelcool1234/.dotfiles/hosts/legion/hardware-configuration.nix).

## Files to inspect first

- [`hosts/legion/drivers.nix`](/home/axelcool1234/.dotfiles/hosts/legion/drivers.nix)
- [`hosts/legion/configuration.nix`](/home/axelcool1234/.dotfiles/hosts/legion/configuration.nix)
- [`hosts/legion/hardware-configuration.nix`](/home/axelcool1234/.dotfiles/hosts/legion/hardware-configuration.nix)
- [`hosts/legion/POST_DRIVER_UPDATE_DEBUG.md`](/home/axelcool1234/.dotfiles/hosts/legion/POST_DRIVER_UPDATE_DEBUG.md)
- [`flake.nix`](/home/axelcool1234/.dotfiles/flake.nix)
- [`nixos-modules/hyprland/hyprland.nix`](/home/axelcool1234/.dotfiles/nixos-modules/hyprland/hyprland.nix)

## Required workflow

### 1. Read the current config

Read the files above before making assumptions.

Pay special attention to:

- imported hardware modules
- `hardware.graphics`
- `hardware.intelgpu`
- `hardware.nvidia`
- `boot.blacklistedKernelModules`
- `services.xserver.videoDrivers`
- the `nvidia-only` specialisation
- Legion-specific helper tooling installed in `environment.systemPackages`
- Hyprland session variables related to NVIDIA

### 2. Collect live machine facts

Use shell commands to inspect the running host.

Preferred commands:

```bash
hostname
uname -r
nixos-version
lscpu
grep MemTotal /proc/meminfo
lspci -D -d ::03xx
lspci -nn
lspci -nnk
ls -1 /sys/class/drm
nvidia-smi
hyprctl -j monitors
cat /proc/cmdline
cat /sys/devices/virtual/dmi/id/product_name
cat /sys/devices/virtual/dmi/id/sys_vendor
cat /sys/devices/virtual/dmi/id/board_name
cat /sys/devices/virtual/dmi/id/bios_version
```

If root would be helpful for a deeper check, do not guess. Ask the user to run the exact sudo command and paste the output.

### 3. Evaluate the effective NixOS configuration

Do not trust only the handwritten file. Check what the module system actually evaluates.

Useful commands:

```bash
nix eval --json .#nixosConfigurations.legion.config.hardware.graphics.enable
nix eval --json .#nixosConfigurations.legion.config.hardware.graphics.enable32Bit
nix eval --json .#nixosConfigurations.legion.config.hardware.intelgpu.driver
nix eval --json .#nixosConfigurations.legion.config.hardware.intelgpu.vaapiDriver
nix eval --json .#nixosConfigurations.legion.config.services.xserver.videoDrivers
nix eval --json .#nixosConfigurations.legion.config.boot.blacklistedKernelModules
nix eval --json .#nixosConfigurations.legion.config.hardware.nvidia.open
nix eval --json .#nixosConfigurations.legion.config.hardware.nvidia.prime.offload.enable
nix eval --json .#nixosConfigurations.legion.config.specialisation
nix eval --raw .#nixosConfigurations.legion.config.system.build.toplevel.drvPath
```

The final `drvPath` evaluation is important because it catches module-graph problems that option-level checks might miss.

### 4. Compare against upstream guidance

Use web browsing aggressively. Prefer primary and project-owned sources.

Minimum sources to check:

- NixOS NVIDIA wiki
- NixOS accelerated video playback guidance
- Hyprland NVIDIA documentation
- `nixos-hardware` Legion 16IAH7H module
- `nixos-hardware` NVIDIA PRIME module
- Nixpkgs NVIDIA module implementation

Suggested references:

- https://wiki.nixos.org/wiki/NVIDIA
- https://wiki.nixos.org/wiki/Accelerated_Video_Playback
- https://wiki.hypr.land/Nvidia/
- https://github.com/NixOS/nixos-hardware/blob/master/lenovo/legion/16iah7h/default.nix
- https://github.com/NixOS/nixos-hardware/blob/master/common/gpu/nvidia/prime.nix
- https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/hardware/video/nvidia.nix

When the topic is technical, rely on primary sources or official project documentation rather than forum summaries.

### 5. Judge the file by these rules

Keep the current config if all of the following are true:

- it still matches the live machine hardware
- it still encodes two explainable, evidence-backed modes:
  - Intel-only default for hybrid firmware mode
  - NVIDIA-only specialisation for dGPU firmware mode
- it avoids pretending hybrid NVIDIA offload is trustworthy unless fresh evidence now proves that it works on this hardware
- it does not duplicate upstream `nixos-hardware` or NixOS defaults unnecessarily
- its comments still match what the machine actually does

Recommend changes if any of the following are true:

- the default Intel-only boot is no longer the most stable hybrid-mode choice
- the `nvidia-only` specialisation no longer matches the last known-good NVIDIA-only behavior
- fresh evidence shows hybrid NVIDIA is finally healthy and the file should be redesigned around that
- a setting is now redundant because upstream already provides it
- comments no longer match reality
- a feature is enabled but the live system suggests it is not working well

Examples of things worth questioning:

- `WLR_NO_HARDWARE_CURSORS=1`
- any claim that PRIME offload is healthy on this Legion
- custom boot kernel params added only as folklore
- `dynamicBoost.enable` when `nvidia-powerd` is noisy or broken
- whether `open = true` is still the right choice inside the `nvidia-only` specialisation
- whether `legion-gpu-mode` still matches the generated GRUB menu titles

### 6. Be conservative about changes

Do not churn the file for style only.

If a setting is ugly but still justified, keep it and improve the explanation.

If you remove a custom knob, explain:

- why it is no longer needed
- what now covers that behavior instead
- what risk or regression to watch after rebuilding

### 7. Preserve and improve documentation

This file is intentionally documented heavily.

If you change [`hosts/legion/drivers.nix`](/home/axelcool1234/.dotfiles/hosts/legion/drivers.nix):

- keep the top-level machine dossier comment accurate
- update the source list if your audit used new references
- explain every new option in plain language
- prefer comments that teach future readers why a choice exists

## Output format for the audit

If no changes are needed, say that explicitly.

Use this structure:

### Verdict

State one of:

- `No change needed`
- `Small update recommended`
- `Rewrite recommended`

### Findings

List issues ordered by severity.

For each finding include:

- file reference
- what is wrong or questionable
- why it matters on this host

### Evidence

Summarize the most relevant live facts and evaluated config values.

### Recommended action

State the smallest sensible next step.

If editing the file, mention what should be added, removed, or kept.

### Sources

Link the sources actually used for that audit.

## Editing rules

- Do not touch [`hosts/legion/hardware-configuration.nix`](/home/axelcool1234/.dotfiles/hosts/legion/hardware-configuration.nix).
- Use `apply_patch` for edits.
- Re-evaluate the Legion system after edits.
- Keep changes surgical unless a real redesign is justified.

## Success criteria

The audit is successful when:

- the agent has checked both the handwritten config and the evaluated config
- live machine facts were gathered instead of assumed
- current upstream guidance was consulted
- the final recommendation is tied to evidence, not folklore
- any resulting `drivers.nix` changes remain understandable to a future human reader
