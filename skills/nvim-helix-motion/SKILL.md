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
  `:byte_range()`, `:text()`, and `:is_empty()`. Its explicit kind distinguishes
  a cursor cell, a selected span, and an empty insertion point; do not infer
  that intent from byte width or add parallel cached cell fields.
- `Selection` owns normalized ranges plus the primary index. Pass it across
  command/state/history boundaries as one value; never encode the primary by
  moving its range to array index 1.
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

2. Choose a constructor that states intent: `range.cursor_cell()` for a block
   cursor, `range.from_span_cells()` for an inclusive selected span (including
   a one-grapheme selection), and `range.empty()` for an insertion boundary.
   Use `range.from_boundaries()` internally and `range.from_byte_range()` only
   at an external byte-coordinate adapter. Do not recreate a generic
   `from_cells` constructor or a boolean `point` option.

3. Read selections through `state.current_selection()` or
   `state.preview_selection()` and publish them through
   `state.set_preview_selection()`. Use `selection:primary()`, `:transform()`,
   `:transform_iter()`, `:filter()`, and the other Selection methods. The old
   range-array state APIs are intentionally absent.

4. Preserve direction explicitly. Decide where both anchor and cursor land,
   including after edits. Do not normalize away backward selections unless the
   Helix command does so.

5. Transform all active ranges together. The primary cursor is the real Neovim
   cursor; other cursors and highlights are renderings of the same selection
   model, not a separate source of truth.

6. Route buffer changes through `Transaction`. Prefer
   `Transaction:track_selection()` and consume `apply().selection`. For edits
   performed by native commands or LSP, use the narrow
   `transaction.track_selection()` escape hatch. Range-level tracking remains
   appropriate for individual inserted spans. Use semantic affinity (`inside`,
   `outside`, `before`, or `after`) instead of raw extmark gravity choices, and
   do not calculate later edits from already-shifted buffer contents.

7. Keep undo history separate from edit construction. `history.undo_scope()`
   brackets native or transaction edits and restores complete Selections; it
   is not the edit transaction itself.

8. Route insert-driven operations through `insert.lua`. One insert session
   normally forms one undo block and synchronizes secondary ranges from the
   local insert-session state.

9. Keep byte math at adapters. Prefer `boundary_to_byte`, `boundary_from_byte`,
   `byte_before_cell`, `byte_after_cell`, `byte_col0_from_grapheme_col`, and
   `grapheme_col_from_byte_col0`. Do not use `#line` as a logical column or pass
   grapheme columns directly to Neovim APIs.

10. Reuse `compare_cells`, `cells_equal`, `next_pos`, `prev_pos`,
   `supports_column`, `is_newline_pos`, and display column helpers rather than
   duplicating coordinate comparison or row/column traversal.

11. Keep pure policies out of `init.lua`: extend focused modules such as
    `integer.lua`, `case.lua`, and `surround.lua`. `init.lua` should coordinate
    prompts, state, history, and editor APIs rather than duplicate algorithms.

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
`parity.lua` as appropriate. Run mapping- and Tree-sitter-driven harnesses with
the real wrapper initialization (without `-u NONE`); those harnesses load
`remaps.lua` explicitly because startup events are not reliable in headless
chunks. Model tests should stay independent of mappings. A test should assert observable buffer text,
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
- Multi-range edits return a complete Selection from one transaction with
  semantic affinity.
- No legacy selection-entry properties or byte-based logical column math were
  reintroduced.
- No range-array state compatibility API or ambiguous range constructor was
  reintroduced.
- Relevant focused harnesses and a load/syntax check were run.
