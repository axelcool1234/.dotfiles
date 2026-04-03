---
name: persistence-migration
description: Use when migrating Nix impermanence persistence from one path shape to another, especially directory-to-file or directory-to-children changes that cause mount conflicts during activation.
metadata:
  short-description: Migrate impermanence path layouts
---

# Persistence Migration

Use this skill for one-time migrations where persisted paths changed shape and activation now fails with errors like:

- `A file already exists at ...`
- `target is busy`
- old parent mount still active while new child mounts or file mounts are being introduced

This is most common when changing:

- one persisted directory into several persisted subdirectories
- one persisted directory into individual persisted files
- one persisted file into a persisted directory

## Overview

Impermanence does not automatically migrate an existing mounted path into a new persistence layout. The usual fix is:

1. Inspect the current mount tree and unit state.
2. Stop or detach child mounts first.
3. Stop or detach the old parent mount.
4. Remove only the home-side blocking targets that the new units need to own.
5. Re-run activation and verify the new units came up.

## Workflow

### 1. Confirm the migration shape

Inspect the persisted path and its children:

```bash
findmnt -R <target-path>
systemctl list-units --all '<escaped-unit-prefix>*' --no-pager
```

Look for a pattern where:

- the old parent mount is still active
- some new child mounts are already active
- new file-level persistence units failed because a file already exists

### 2. Stop child mounts before the parent

If the new layout created nested mounts under the old parent, stop those first. If a stop fails because the path is busy, use a lazy unmount for the specific child mountpoint.

Typical commands:

```bash
sudo systemctl stop <child-mount-1> <child-mount-2> ...
sudo umount -l <busy-child-path>
```

Do not start by removing files blindly. Clear the mount stack first.

### 3. Detach the old parent mount

Once children are down, stop the old parent mount. If systemd still reports it busy, use a lazy unmount.

```bash
sudo systemctl stop <old-parent-mount-unit>
sudo umount -l <target-path>
```

### 4. Remove only home-side blockers

Delete only the live mountpoint-side files or directories that are preventing the new units from taking ownership.

Examples:

- `/home/user/.code/auth.json`
- `/home/user/.config/app/state.json`

Do not delete the backing store under `/persist/...` unless the user explicitly wants data removed.

After detaching mounts, remove the blocking targets:

```bash
rm -f <blocking-file> ...
rm -rf <blocking-dir> ...
```

Only remove paths that the new persistence layout is about to recreate.

### 5. Re-run activation

Run the appropriate activation command again:

```bash
sudo nixos-rebuild switch
```

Then verify:

```bash
findmnt -R <target-path>
systemctl list-units --all '<escaped-unit-prefix>*' --no-pager
```

Success looks like:

- the old parent mount unit is gone if it was removed from config
- the new file and directory mounts are active
- activation completes without `A file already exists at ...`

## Guardrails

- Prefer `sudo -n true` first if you need to know whether non-interactive sudo works.
- If the current tool session is using the persisted path, expect some child mounts to be busy and use lazy unmounts.
- Never delete `/persist/...` as part of the migration unless the user explicitly asks to discard persisted data.
- Treat this as a one-time migration. Once activation succeeds, future rebuilds should be clean.

## Example pattern

Directory-to-files migration example:

- old: `~/.code` persisted as one directory mount
- new: `~/.code/debug_logs`, `~/.code/sessions`, and several `~/.code/*.json` file mounts

Typical recovery:

1. Unmount active child mounts under `~/.code`
2. Unmount the old `~/.code` parent mount
3. Remove conflicting `~/.code/*.json` files on the home side
4. Re-run `nixos-rebuild switch`

## Completion Checklist

- [ ] Old and new mount layouts were inspected with `findmnt -R`
- [ ] Child mounts were detached before the parent
- [ ] Only blocking mountpoint-side targets were removed
- [ ] Backing data under `/persist` was preserved
- [ ] Activation was rerun and new mount units verified
