---
name: system-health-check
description: Run an evidence-based health check of the current NixOS machine after a reboot, deployment, update, or reported system or desktop problem. Use for requests such as "check that everything looks good" or "verify this reboot." Do not use for broad host policy audits or make repairs unless the user asks.
metadata:
  short-description: Verify live NixOS health after changes
---

# System Health Check

Verify whether the current NixOS boot and user session are healthy. Reconcile
three sources of truth:

- the generation that was intended and is currently booted
- relevant policy in this dotfiles repository and its effective NixOS options
- live units, devices, and logs from the current boot

This is an operational check, not a broad hardware or host-policy audit. Use
`host-audit` instead when the user wants a baseline inventory, a policy dossier,
or durable audit documentation.

## Safety Boundary

Health checks are read-only by default. Do not rebuild, switch generations,
restart services, unlock keyrings, change settings, or remove state unless the
user separately asks for a repair. Commands that merely query Nix evaluation,
systemd, journals, D-Bus properties, mounts, or devices are in scope.

Do not read keyring contents, password hashes, tokens, or unrelated environment
variables. Secret Service `Locked` properties are safe to inspect.

## Baseline Collection

From the dotfiles root, run the repository collector:

```bash
nix run .#system-health-check
```

The command emits bounded JSON and never changes system state. Its generic
baseline includes all failed or restarted services, anomaly journals, boot
warnings and crash signatures, coredumps, kernel taint, storage and memory
pressure, networking and time synchronization, plus optional desktop/device
probes. Add relevant units when a reported problem involves a service not
covered by the selected-service defaults:

```bash
nix run .#system-health-check -- \
  --system-service <unit> \
  --user-service <unit>
```

Treat command failures in the JSON as missing evidence, not automatically as a
system failure. A user-bus query may need to run outside a filesystem sandbox
even when the machine itself is healthy.

## Verify the Deployment

At minimum, establish:

1. `/run/current-system` and `/nix/var/nix/profiles/system` resolve to the same
   generation when the user says they booted the latest one.
2. The effective configuration still produces the expected host generation:

   ```bash
   nix eval --raw .#nixosConfigurations.<host>.config.system.build.toplevel
   ```

3. Kernel and NixOS versions match the relevant host policy.
4. System and user failed-unit lists are empty or every entry is explained.

Inspect the host file and shared module responsible for the changed behavior.
Do not read the entire repository when a narrow policy path is enough. If the
change came from a flake update, compare the exact old and new package outputs
before attributing a regression to nixpkgs.

## Interpret Live State

The collector is a starting point, not an exhaustive definition of health. Use
its anomalies and the user's symptoms to choose the next read-only probe. New
problems should be investigated from their actual unit, device, process, or log
evidence; do not require a failure to match a signature from an earlier audit.

Before focusing on the desktop, consider generic system evidence:

- failed or restarted services and their current-boot journals
- coredumps, OOM events, segfaults, lockups, I/O errors, and GPU resets
- unexpected kernel taint reasons or kernel-command-line changes
- full or read-only persistent filesystems, swap exhaustion, memory pressure,
  zombie processes, and abnormal load
- missing network routes, DNS failures, or unsynchronized time
- device-specific errors surfaced by the boot journal

An `active` service is not sufficient evidence of health. Also check:

- `NRestarts`, `ExecMainStatus`, and `ActiveEnterTimestamp`
- current-boot journal timestamps around any restart or visible glitch
- both sides of a protocol failure, such as a shell client and compositor
- whether hardware-facing services have a usable device, not merely a daemon
- whether a warning is new, recurring, or an expected limitation

For this dotfiles desktop, apply these focused checks when relevant:

- **Noctalia/Niri:** confirm both user units have zero unexpected restarts;
  correlate `wp_presentation`, client-disconnect, rendering, and output logs.
- **Greeter:** confirm greetd waited for the configured DRM device, then inspect
  greeter scale, cursor, GPU, EGL, and session-open messages.
- **Bluetooth:** require a powered controller, active BlueZ service, and the
  desktop shell's registered BlueZ agent.
- **GNOME Keyring:** confirm PAM reported a successful unlock and both the login
  and default Secret Service collections report `Locked=false`. A successful
  daemon start alone does not prove the collection unlocked.
- **Monitors:** compare live names, modes, scales, transforms, and logical
  positions with `hostVars.monitors`; distinguish compositor support from a
  greeter parser limitation.
- **Impermanence:** when state unexpectedly disappears or reverts, verify the
  live mount source and the declared persisted path before blaming the app.

Follow symptoms into targeted logs rather than expanding every check
unconditionally. Use `journalctl -b` for the current boot and `journalctl -b -1`
only when comparison with the preceding boot will resolve an ambiguity.

## Verdict Standard

Use one of these verdicts:

- `Healthy`: intended generation is booted, required services and devices are
  healthy, no unexplained restarts or relevant errors remain.
- `Healthy with warnings`: core behavior is correct and remaining warnings are
  understood, bounded, and non-blocking.
- `Needs attention`: evidence shows a failed unit, unexpected restart, locked
  required secret store, missing device, generation mismatch, or unexplained
  high-severity error.
- `Unable to verify`: permissions or missing evidence prevent a responsible
  conclusion.

Lead with the verdict. Summarize the most important confirmations and problems,
including exact restart counts or timestamps where useful. Separate harmless
residual warnings from failures. Recommend the smallest next action, and do not
turn a check-only request into an implementation task.

## Improve Coverage Deliberately

After resolving an issue while using this skill, briefly review whether the
diagnosis exposed a reusable gap in either this workflow or
`pkgs/system-health-check`:

- Suggest an update when a generally useful, read-only signal was missing, a
  current probe was misleading or too noisy, or a recurring diagnosis needed
  undocumented reasoning.
- Prefer generic detection and interpretation guidance over matching one exact
  error string, machine, package version, or historical incident.
- Keep optional or host-specific probes conditional so the baseline remains
  portable and bounded.
- Do not suggest churn when existing guidance already covered the issue and the
  investigation merely applied it.

State the proposed coverage improvement in the final report when worthwhile.
Do not edit the skill or collector as part of an ordinary health check unless
the user asks for that change.
