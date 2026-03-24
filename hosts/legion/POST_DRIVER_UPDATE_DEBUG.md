# Legion Post-Update Graphics Validation

Use this guide after changing [`hosts/legion/drivers.nix`](/home/axelcool1234/.dotfiles/hosts/legion/drivers.nix), rebuilding the system, and rebooting.

This is a host-specific validation guide for the `legion` laptop.

## Why this guide exists

This machine can behave in two very different ways depending on both:

- firmware GPU mode
- which NixOS boot entry you select

Current supported operating model:

1. `Hybrid firmware mode` + normal boot entry
   This should behave as `Intel-only`.
2. `dGPU-only firmware mode` + `nvidia-only` specialisation
   This should behave as `NVIDIA-only`.

Both of those supported combinations have now been re-tested successfully on this
Legion.

Helpful host-local tool:

- `legion-gpu-mode status`
- `legion-gpu-mode hybrid`
- `legion-gpu-mode nvidia`

This helper uses LenovoLegionLinux plus `grub-reboot` so the firmware GPU mode and
the next GRUB entry stay aligned.

Important:

- Hybrid mode with a healthy NVIDIA offload path is *not* currently treated as a trusted mode on this Legion.
- Past investigation found that hybrid mode repeatedly brought the Intel GPU up correctly while the NVIDIA dGPU failed with errors such as:
  - `RmInitAdapter failed`
  - `Failed to allocate NvKmsKapiDevice`
  - `nvidia-smi: No devices were found`

## When to use this guide

Use it after:

- editing [`hosts/legion/drivers.nix`](/home/axelcool1234/.dotfiles/hosts/legion/drivers.nix)
- adding or removing Intel / NVIDIA / Hyprland graphics settings
- changing BIOS or Lenovo Vantage GPU mode settings
- updating NixOS, the kernel, the NVIDIA driver, Hyprland, or `nixos-hardware`

## Step 1: Confirm what you actually booted

Check the running kernel and command line:

```bash
uname -r
cat /proc/cmdline
```

Check the booted system symlink too:

```bash
readlink -f /run/booted-system
```

Good signs:

- the kernel version matches the new generation you expected
- the `init=` path points at the generation you expected

## Step 2: Determine the firmware GPU mode

Run:

```bash
lspci -D -d ::03xx
ls -1 /sys/class/drm
```

Interpretation:

### Hybrid firmware mode

- `lspci` shows both Intel and NVIDIA display controllers
- the Intel GPU is visible to Linux

### dGPU-only firmware mode

- `lspci` shows only the NVIDIA display controller
- the Intel display device is not visible to Linux as a graphics controller

Important:

- If only NVIDIA appears, Linux cannot make the Intel desktop path happen because the iGPU is not being presented as a usable graphics device.
- In that situation, the fix is not usually in `drivers.nix`; it is usually a BIOS / firmware / MUX / vendor-control setting.

## Step 3: Confirm which *configuration mode* you intended

Current `drivers.nix` policy:

- normal boot entry = `Intel-only`
- `nvidia-only` specialisation = `NVIDIA-only`

This means the safe combinations are:

- firmware `hybrid` + normal boot entry
- firmware `dGPU-only` + `nvidia-only` specialisation

Potentially bad / confusing combinations are:

- firmware `dGPU-only` + normal boot entry
- firmware `hybrid` + `nvidia-only` specialisation

The preferred way to avoid those mismatches is to use `legion-gpu-mode` instead of
changing firmware mode manually and then trying to remember the matching boot entry.

## Step 4: Check the basic driver stack

Run:

```bash
lspci -nnk | sed -n '/VGA compatible controller/,+3p;/3D controller/,+3p'
lsmod | egrep '^(nvidia|i915)'
nvidia-smi
```

Interpretation by mode:

### Expected in Intel-only mode

- Intel `i915` is present
- Hyprland works
- NVIDIA may be blacklisted or otherwise intentionally absent from normal operation
- `nvidia-smi` failing is not automatically a bug in this mode

### Expected in NVIDIA-only mode

- the NVIDIA card uses the `nvidia` driver
- `nvidia-smi` works
- Hyprland can use NVIDIA as the active desktop GPU

Red flags:

- Intel-only mode but Intel is not healthy enough to render the desktop
- NVIDIA-only mode but `nvidia-smi` fails
- repeated adapter-init failures:
  - `RmInitAdapter failed`
  - `Failed to allocate NvKmsKapiDevice`
  - `No devices were found`

## Step 5: Check service health

Run:

```bash
systemctl --failed --no-legend
systemctl --user --failed --no-legend
systemctl --user status xdg-desktop-portal.service xdg-desktop-portal-hyprland.service
```

Good signs:

- no failed system units
- no failed user units
- portal services are active in the user session

## Step 6: Check important boot warnings

Run:

```bash
journalctl -b -p 4 --no-pager | rg -i 'nvidia|nouveau|i915|drm|gpu|acpi|pci|hypr|wayland|bios'
```

Interpret carefully:

- ACPI firmware warnings are often real firmware noise rather than a Linux config bug
- duplicate DBus or portal service registration warnings are annoying but often non-fatal
- one-off `udev` noise around device nodes can be harmless if the driver ends up healthy

Escalate if you see:

- repeated GPU resets
- Xid errors
- hard Wayland / DRM failures
- repeated compositor crashes
- repeated NVIDIA adapter-init failures such as:
  - `RmInitAdapter failed`
  - `Failed to allocate NvKmsKapiDevice`
  - `nvidia-smi: No devices were found`

## Step 7: Check what is actually driving the desktop

Run:

```bash
nvidia-smi pmon -c 1
hyprctl -j monitors
```

Interpretation:

### Intel-only mode

Expected:

- Hyprland is stable on the internal display
- it is fine if NVIDIA is not actively participating

### NVIDIA-only mode

Expected:

- Hyprland and Xwayland show up on the NVIDIA GPU
- NVIDIA power draw will be higher than in Intel-only mode
- the internal panel should prefer `2560x1600@165` because the Legion Hyprland
  config now pins that mode explicitly

## Step 8: Check power behavior

Run:

```bash
for f in /sys/bus/pci/devices/0000:01:00.0/power/{control,runtime_status,runtime_usage}; do
  printf '%s: ' "$f"
  cat "$f"
done

nvidia-smi --query-gpu=name,driver_version,pstate,power.draw,temperature.gpu,utilization.gpu,memory.used --format=csv,noheader
```

Interpretation:

### Intel-only mode

Expected:

- it is okay if NVIDIA is effectively absent from active desktop work
- `nvidia-smi` may fail if the mode is intentionally not using NVIDIA at all

### NVIDIA-only mode

Expected:

- NVIDIA stays active
- power draw is higher
- that is normal because the dGPU is intentionally the primary device

## Step 9: Check whether the result matches the intended policy

Current intended policy encoded by [`drivers.nix`](/home/axelcool1234/.dotfiles/hosts/legion/drivers.nix):

- default boot is stable Intel-only behavior
- NVIDIA-only behavior is an explicit separate specialisation
- hybrid NVIDIA offload is *not* the success target right now

If the machine is stable and behaving in one of those two modes, the config is doing its job.

If you unexpectedly find a healthy hybrid NVIDIA path in the future, that is a reason to re-audit the design rather than silently assuming the old conclusion still holds.

## Special findings already established on this Legion

These are known historical facts for this host and should inform future debugging:

- `dGPU-only` firmware mode previously booted and ran Hyprland successfully with NVIDIA active
- `hybrid` firmware mode successfully brought up the Intel desktop path
- `hybrid` firmware mode repeatedly failed to produce a healthy NVIDIA device across multiple tested NVIDIA configurations

That means future debugging should begin from the assumption that the default stable modes are:

- Intel-only
- NVIDIA-only

and not from the assumption that hybrid NVIDIA offload should work.

## Audit output template

Use this structure when reporting the result:

### Verdict

Choose one:

- `Healthy in intended mode`
- `Healthy, but wrong mode was booted`
- `Configuration issue found`
- `Needs deeper investigation`

### Observed firmware mode

State one:

- `Hybrid`
- `dGPU-only`
- `Unclear`

### Observed config mode

State one:

- `Intel-only default boot`
- `nvidia-only specialisation`
- `Unclear`

### Evidence

Summarize:

- visible GPUs in PCI / DRM
- whether Hyprland is stable
- whether `nvidia-smi` works when it is supposed to
- relevant service and journal findings

### Recommended action

Examples:

- keep `drivers.nix` as-is
- boot the right firmware / specialisation combination
- investigate a new regression
- re-audit if previously broken hybrid NVIDIA suddenly starts working

## Success criteria

This validation is successful when:

- you know which firmware mode the laptop is in
- you know which configuration mode was booted
- you know whether that combination is one of the intended supported combinations
- you have checked both runtime health and boot / service health
- you can explain surprising GPU behavior using evidence rather than guesswork
