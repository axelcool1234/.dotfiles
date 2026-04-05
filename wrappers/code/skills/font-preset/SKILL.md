---
name: font-preset
description: Use when creating or updating a font preset under `fonts/`, especially when font family names, package attr paths, or Kitty PostScript names must be verified against nixpkgs.
metadata:
  short-description: Create or update a dotfiles font preset
---

# Font Preset

Use this skill when the user wants to add, revise, or validate a font preset in
this dotfiles repo.

This skill is specific to the current font preset architecture:

- preset data lives under `fonts/*.nix`
- preset files are discovered automatically from `fonts/*.nix`
- the active preset is selected in `defaults.nix` via the local preset name
- the schema is declared under `preferences.defaults.fonts`
- consumers read the shared font roles and do their own string formatting

This is not a generic theming skill. It is only for font presets.

## Current Model

Match the repo's actual font role shape.

Current roles:

- `ui`
- `monospace`
- `terminal`
- `emoji`
- `symbols`

Current attribute usage:

- `ui`: `family`, `size`, `packageAttrPath`
- `monospace`: `family`, `size`, `packageAttrPath`
- `terminal`: `family`, `size`, `packageAttrPath`, `postscriptName` optional
- `emoji`: `family`, `packageAttrPath`
- `symbols`: `family`, `packageAttrPath`

Do not add extra roles or attributes unless the repo starts consuming them.
In particular, do not reintroduce old roles like notifications/popups unless the
current repo grows consumers for them again.

## Files To Inspect First

- `defaults.nix`
- the target preset file under `fonts/`
- `modules/features/fonts.nix`
- `modules/features/theming/noctalia-shell/gtk.nix`
- `modules/features/theming/noctalia-shell/qt.nix`
- `wrappers/kitty/default.nix`
- `wrappers/zathura.nix`

## Workflow

### 1. Confirm the preset shape

Read the current preset files and mirror their structure exactly.

Questions to answer:

- is this a new preset or an edit to an existing one?
- which role values actually differ from an existing preset?
- does the requested font family need both normal and Nerd Font variants?
- does the requested preset actually need a `postscriptName`, or can it be
  omitted?

### 2. Resolve the nixpkgs package attr path

Use Nix or the Nix MCP server to confirm the package name instead of guessing.

Useful approaches:

```bash
nix search nixpkgs <font-name>
```

Or use the Nix MCP/package search tooling to verify package names like:

- `jetbrains-mono`
- `fira`
- `nerd-fonts.jetbrains-mono`
- `nerd-fonts.fira-code`
- `noto-fonts-color-emoji`
- `nerd-fonts.symbols-only`

When the package attr path is nested, store it as a string list, for example:

```nix
[ "nerd-fonts" "fira-code" ]
```

### 3. Verify the real runtime family name

Do not assume the runtime family name matches the nixpkgs attr name.

For example:

- package attr: `nerd-fonts.fira-code`
- runtime family: `FiraCode Nerd Font Mono`

Inspect the installed font files when needed:

```bash
out=$(nix build --no-link --print-out-paths nixpkgs#nerd-fonts.fira-code)
find "$out" -type f \( -iname '*.ttf' -o -iname '*.otf' \)
```

### 4. Verify Kitty PostScript name only when needed

Only terminal fonts may need `postscriptName`, and only when Kitty benefits from
it.

Use `fc-scan` on the exact font file to confirm the real value:

```bash
fc-scan /path/to/font.ttf | rg 'family:|fullname:|postscriptname:|style:'
```

Example outcome:

- family: `FiraCode Nerd Font Mono`
- postscriptname: `FiraCodeNFM-Reg`

If you cannot verify a PostScript name, omit it rather than guessing.

### 5. Add or update the preset

Put the pure data in `fonts/<preset-name>.nix`.

No manual registry update is needed because `defaults.nix` discovers preset
files automatically.

If the user wants the new preset selected immediately, update the local preset
selection in `defaults.nix`.

Keep the preset file as pure data only. Do not recreate option types or schema
inside the preset file.

### 6. Validate repo behavior

After changing a preset, validate at least one host-side and one wrapper-side
consumer.

Recommended checks:

```bash
nix eval .#nixosConfigurations.legion.config.fonts.fontconfig.defaultFonts --json
nix build .#packages.x86_64-linux.kitty
```

Optional targeted checks:

```bash
nix build .#packages.x86_64-linux.zathura
```

## Guardrails

- Keep preset files as pure data only.
- Do not duplicate the option schema from `defaults.nix` in the preset files.
- Do not add unused fields just because a font package exposes them.
- Prefer matching the current role/attribute footprint over preserving old repo
  symmetry.
- Prefer exact family names over guessed transformations from package names.
- Prefer exact `postscriptName` verification over guessing.

## Completion Checklist

- [ ] Preset file added or updated under `fonts/`
- [ ] New preset file is discoverable by the automatic font preset import flow
- [ ] Family names verified against the actual installed font files where necessary
- [ ] `packageAttrPath` values verified against nixpkgs
- [ ] `postscriptName` verified with `fc-scan` when present
- [ ] At least one `nix eval` and one `nix build` validation completed
