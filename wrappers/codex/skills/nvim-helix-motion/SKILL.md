---
name: nvim-helix-motion
description: Add, fix, or audit Neovim motions, selections, edits, and keymaps that should behave like Helix in this dotfiles repo, especially under `wrappers/neovim/lua/axelcool1234/helix/` and `remaps.lua`.
metadata:
  short-description: Implement Helix-compatible Neovim motions
---

# Neovim Helix Motion

Use this skill for the dotfiles repo's plugin-free Helix emulation layer. Local
selections and multicursor behavior are not delegated to a cursor plugin.

## Inspect the Relevant Sources

Read the local implementation before making nontrivial changes; this skill is a
map, not a substitute for current code.

- `wrappers/helix.nix` for local Helix overrides
- `wrappers/neovim/lua/axelcool1234/remaps.lua` for Neovim mappings
- `wrappers/neovim/lua/axelcool1234/helix/position.lua`
- `wrappers/neovim/lua/axelcool1234/helix/range.lua`
- `wrappers/neovim/lua/axelcool1234/helix/selection.lua`
- `wrappers/neovim/lua/axelcool1234/helix/transaction.lua`
- `wrappers/neovim/lua/axelcool1234/helix/state.lua`
- the behavior module involved: usually `motion.lua`, `match.lua`, `insert.lua`,
  or `init.lua`
- the corresponding files under `wrappers/neovim/tests/`, especially
  `selection_model.lua` for coordinate/model changes and `match.lua` for the
  `m` family

Compare stock Helix behavior, local overrides, and the existing Neovim
implementation. Local overrides win. For example, this repo maps `H`/`L` to
previous/next buffer and `g.k` to hover.

## Coordinate and Selection Model

Keep these layers distinct:

- A cell position is `{ row, grapheme_col }`, both 1-indexed. It identifies a
  selectable grapheme or the synthetic newline cell.
- A boundary is a gap between cells, represented by `{ row, col }`; its column
  is a 0-indexed grapheme boundary.
- Neovim, Tree-sitter, LSP, and extmark APIs use byte columns. Convert only at
  an adapter boundary in `position.lua`.
- `Range` stores directional, half-open `anchor` and `head` boundaries. Use
  methods such as `:anchor_cell()`, `:cursor()`, `:start_cell()`, `:end_cell()`,
  `:byte_range()`, `:text()`, and `:is_empty()`. Do not add parallel cached
  cell fields.
- `Selection` owns normalized ranges plus the primary index.
- `Transaction` owns buffer edits and range tracking. Commands describe edits
  in logical boundaries; transaction code performs byte conversion and extmark
  tracking.
- `state.lua` owns per-window, per-buffer selections, mode flags, and rendering.
  Preferred display columns and exceptional visual cursor cells live on each
  `Range`, not in parallel arrays.

Grapheme columns are not byte offsets or Unicode scalar counts. Always use the
grapheme helpers in `position.lua`; regressions should cover multibyte text such
as `∀` and multi-codepoint grapheme clusters.

Newline is a first-class selectable cell. On a non-final line,
`cursor_max_column()` may be one past the last text grapheme because that cell
represents the newline. Motions and edits must decide how newline cells behave,
not discard them as invalid columns.

## Implementation Rules

1. Identify the Helix command and observable behavior, not only its key. Treat
   notation such as `ms<char>` as a prompted command family.

2. Construct real ranges with `range.from_cells`, `range.from_boundaries`, or
   `range.from_byte_range` at an external byte-coordinate adapter. The old
   table-shaped selection entries and their compatibility property names no
   longer exist.

3. Read selections through `state.current_selection()`, `state.current_ranges()`,
   `state.preview_ranges()`, and `state.primary_range()`. Publish them through
   `state.set_preview_selection()` or `state.set_preview_ranges()`.

4. Preserve direction explicitly. Decide where both anchor and cursor land,
   including after edits. Do not normalize away backward selections unless the
   Helix command does so.

5. Transform all active ranges together. The primary cursor is the real Neovim
   cursor; other cursors and highlights are renderings of the same selection
   model, not a separate source of truth.

6. Route buffer changes through `Transaction`. Use `track_ranges()` or
   `Transaction:track_range()` with semantic affinity (`inside`, `outside`,
   `before`, or `after`) instead of exposing raw extmark gravity choices in
   commands. Do not edit one range and then calculate later ranges from shifted
   buffer contents.

7. Route insert-driven operations through `insert.lua`. One insert session
   normally forms one undo block and synchronizes secondary ranges from the
   local insert-session state.

8. Keep byte math at adapters. Prefer `boundary_to_byte`, `boundary_from_byte`,
   `byte_before_cell`, `byte_after_cell`, `byte_col0_from_grapheme_col`, and
   `grapheme_col_from_byte_col0`. Do not use `#line` as a logical column or pass
   grapheme columns directly to Neovim APIs.

9. Reuse `next_pos`, `prev_pos`, `supports_column`, `is_newline_pos`, and display
   column helpers rather than duplicating row/column traversal.

For surround commands, snapshot all ranges before editing and apply the changes
through one transaction. After `ms<char>`, preserve the Helix selection landing
behavior around the inserted delimiters. For clone commands such as `C` or
`<A-c>`, retain the original ranges and append clones. For vertical movement,
preserve each range's preferred display column across short or wide-character
lines.

## Validation

Use the real Nix-built wrapper where practical:

```bash
nix run .#neovim -- --headless '+lua print("wrapper-ok")' +qa!
```

New files must be visible to the Git-based Nix source snapshot. `git add -N`
is sufficient to make an untracked path visible without staging its contents.

Run the focused harnesses relevant to the change. For model or Unicode work,
include at least:

```bash
nix run .#neovim -- --headless -u NONE \
  --cmd 'set runtimepath+=/absolute/path/to/.dotfiles/wrappers/neovim' \
  -l wrappers/neovim/tests/selection_model.lua
```

Also run `word_motion.lua`, `jumplist.lua`, `match.lua`, `motion.lua`, or
`parity.lua` as appropriate. A test should assert observable buffer text,
selection text, direction, cursor cell, range count, or undo behavior—not only
that a mapping exists.

Headless `feedkeys()` and mapping-description checks can differ from live UI
behavior. Treat a known headless limitation separately from model/edit
regressions, and use direct command calls for Unicode and transaction tests when
possible.

When useful, port behavioral cases from:

- `~/Projects/helix/helix-term/tests/test/movement.rs`
- `~/Projects/helix/helix-term/tests/test/commands.rs`
- `~/Projects/helix/helix-core/src/selection.rs`
- `~/Projects/helix/helix-core/src/transaction.rs`
- `~/Projects/helix/helix-core/src/surround.rs`

## Completion Check

- Coordinate space is explicit at every external API boundary.
- Multibyte graphemes and newline cells were considered.
- Range direction, primary selection, and preferred display columns survive.
- Multi-range edits use one transaction with semantic affinity.
- No legacy selection-entry properties or byte-based logical column math were
  reintroduced.
- Relevant focused harnesses and a load/syntax check were run.
