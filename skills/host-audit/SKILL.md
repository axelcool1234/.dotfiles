---
name: host-audit
description: Use when auditing a host under `hosts/<name>`, whether it is a first-pass audit for a new host or a re-audit of an existing one, especially when handwritten host policy must be checked against live machine behavior.
metadata:
  short-description: Audit NixOS host reality vs repo policy
---

# Host Audit

Use this skill when the user wants a machine-specific audit for a host in this
dotfiles repo.

This skill is for evidence-backed host audits, not generic NixOS advice. It is
meant to produce or update documentation like:

- a baseline host audit after install or reinstall
- a re-audit after kernel, firmware, GPU, storage, or impermanence changes
- a focused policy audit for a host-local file such as `drivers.nix`

The core standard is:

- inspect the repo first
- collect live machine facts second
- evaluate the effective NixOS config, not just handwritten files
- preserve existing host-specific conclusions unless fresh evidence disproves them
- write down verdicts, triggers, and evidence clearly enough that future audits do
  not restart from zero

## Audit Modes

Choose the smallest mode that matches the request.

### 1. Baseline host audit

Use for a new host, a reinstall, or a broad "is this host healthy and correctly
represented in the repo?" request.

Questions to answer:

- what hardware and storage layout does the host actually have?
- what important host-level policies are encoded in the repo?
- does the live machine match those policies?
- what is healthy, broken, intentional, or provisional?

### 2. Re-audit of an existing host

Use when a host already has audit docs and the user wants to confirm whether the
previous conclusions still hold.

Questions to answer:

- which earlier conclusions are still true?
- what changed in hardware, firmware, kernel, NixOS, storage, or behavior?
- do existing docs need a small update or a rewrite?

### 3. Focused policy audit

Use when a host-local file such as `drivers.nix`, `firewall.nix`, or
`impermanence.nix` is the main target.

Questions to answer:

- does the file still match the real host?
- is it duplicating upstream defaults unnecessarily?
- are comments and encoded policy still accurate?
- is the smallest sensible change "keep", "small update", or "rewrite"?

## Files To Inspect First

Start with the host directory and only expand outward as needed.

Always inspect:

- `hosts/<host>/configuration.nix`
- `hosts/<host>/hardware-configuration.nix`
- `hosts/<host>/impermanence.nix` if present
- any existing audit docs in that host directory

Inspect host-local policy files when relevant, for example:

- `hosts/<host>/drivers.nix`
- `hosts/<host>/firewall.nix`
- `hosts/<host>/networking.nix`
- host-specific helper docs such as post-change validation guides

Inspect flake-level context only when needed, for example:

- `flake.nix`
- imported modules referenced by the host
- shared modules that clearly affect the audited behavior

For existing hosts, treat prior audit docs as historical evidence, not as truth.
They should shape your investigation, but live facts and evaluated config win if
they conflict.

## Workflow

### 1. Build the repo-side picture

Read the relevant host files before making assumptions.

Extract:

- machine identity and intended role
- imported hardware profiles or shared modules
- storage layout and impermanence design
- boot/kernel choices
- graphics, networking, or service policy that is host-specific
- comments that claim certain behaviors are known-good or known-bad

When a file has a long dossier comment, like `hosts/legion/drivers.nix`, preserve
that style of documentation. It exists to save future audits time.

### 2. Build the live-machine picture

Use shell commands to inspect the running system. Prefer direct evidence over
guesswork.

Common baseline commands:

```bash
hostname
uname -r
nixos-version
lscpu
grep MemTotal /proc/meminfo
lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,PARTLABEL,MOUNTPOINTS
findmnt -R /
cat /proc/cmdline
systemctl --failed --no-legend
systemctl --user --failed --no-legend
journalctl -b -p 0..4 --no-pager
```

Add domain-specific commands when needed.

Storage / impermanence examples:

```bash
findmnt -R /persist
btrfs subvolume list /
```

Graphics / laptop examples:

```bash
lspci -D -d ::03xx
lspci -nnk
ls -1 /sys/class/drm
nvidia-smi
hyprctl -j monitors
cat /sys/devices/virtual/dmi/id/product_name
cat /sys/devices/virtual/dmi/id/sys_vendor
cat /sys/devices/virtual/dmi/id/board_name
cat /sys/devices/virtual/dmi/id/bios_version
```

If deeper inspection requires root and you cannot do it directly, ask for the
exact command output rather than guessing.

### 3. Evaluate the effective NixOS configuration

Do not trust handwritten files alone. Confirm what the module system actually
produces.

Start with:

```bash
nix eval --raw .#nixosConfigurations.<host>.config.system.build.toplevel.drvPath
```

Then evaluate the specific options that matter to the audit, for example:

- boot/kernel selections
- graphics settings
- service enablement
- impermanence preferences
- specialisations

Use this step to catch module-graph problems, stale comments, and settings that
are overridden elsewhere.

### 4. Compare policy, live facts, and prior docs

Your job is to reconcile three things:

- the handwritten intent in the repo
- the live behavior of the host
- the previous documented conclusions

When these disagree:

- prefer live evidence over old prose
- prefer evaluated config over assumptions about handwritten files
- keep proven host-specific conclusions unless new evidence disproves them

Examples from this repo:

- a storage audit may show that a login freeze is really a kernel regression, not
  a Disko or impermanence failure
- a graphics audit may show that a theoretically supported mode is still not a
  trusted operating mode on one exact laptop

### 5. Decide the verdict conservatively

Use one of these verdict classes unless the user asked for a different format:

- `No change needed`
- `Small update recommended`
- `Rewrite recommended`
- `Needs deeper investigation`

Prefer the smallest justified change. Do not churn host files for style only.

### 6. Preserve and improve documentation

If the audit leads to edits:

- keep host dossier comments accurate
- update audit markdown files when conclusions change
- add re-audit triggers for the next person
- record the commands or evidence that matter most
- explain why a host-specific choice exists, not just what it sets

Do not silently remove strongly justified host-local policy just because upstream
has become cleaner unless you can show the replacement behavior and its risk.

## Output Structure

Use this structure for the audit result unless the user asked for a different one.

### Verdict

State the overall judgment in one line.

### Findings

List issues or confirmations ordered by severity.

Each finding should include:

- file reference when applicable
- what is wrong, right, or questionable
- why it matters on this exact host

### Evidence

Summarize the most relevant live facts and evaluated config values.

### Recommended Action

State the smallest sensible next step.

Examples:

- keep the current host files as-is
- make a surgical update to one host-local policy file
- update the audit markdown without changing config
- gather one missing root-only fact before editing

### Re-Audit Triggers

List future events that should trigger another audit, such as:

- kernel or firmware changes
- GPU strategy changes
- storage layout or impermanence redesign
- hardware replacement
- upstream module changes that may make a host-local workaround obsolete

### Sources

List the files, commands, and web sources actually used.

## Editing Rules

- Use `apply_patch` for edits.
- Keep changes surgical unless the evidence justifies a redesign.
- Do not edit autogenerated hardware files unless the user explicitly asks.
- If you change a host-local policy file, consider whether the host's audit docs
  and validation docs also need updating.
- When browsing for technical guidance, prefer primary project sources and official
  docs.

## Success Criteria

The audit is successful when:

- the host's intended policy is clear
- the live machine facts are clear
- the evaluated NixOS config was checked
- the verdict is evidence-backed rather than speculative
- the resulting docs make future re-audits faster
