---
name: nvim-helix-motion
description: Use when adding, fixing, or auditing Neovim motions and keymaps that should behave like Helix motions in this dotfiles repo, especially under `wrappers/neovim/lua/axelcool1234/remaps.lua`.
metadata:
  short-description: Implement Helix-compatible Neovim motions
---

# Neovim Helix Motion

Use this skill when the user asks to add or fix a Neovim keybinding so it
matches Helix behavior, including local custom Helix bindings from this repo.

This skill is specific to the dotfiles Neovim wrapper. It is not generic
Neovim plugin advice.

The current Neovim Helix layer is plugin-free for multicursor behavior.
Selections are modeled locally, not delegated to `multicursor-nvim` or another
cursor plugin.

## Files To Inspect First

Always read the relevant local source before changing code:

- `wrappers/helix.nix`
- `wrappers/neovim/lua/axelcool1234/remaps.lua`
- `wrappers/neovim/lua/axelcool1234/helix/init.lua`
- `wrappers/neovim/lua/axelcool1234/helix/position.lua`
- `wrappers/neovim/lua/axelcool1234/helix/state.lua`
- `wrappers/neovim/lua/axelcool1234/helix/motion.lua`
- `wrappers/neovim/lua/axelcool1234/helix/match.lua` when working on the `m` family
- `wrappers/neovim/lua/axelcool1234/helix/insert.lua`
- `wrappers/neovim/tests/match.lua` when changing matching/surround behavior
- `wrappers/neovim/default.nix` when a real dependency may need to be added or removed

This skill can become stale as the Helix emulation layer evolves. Before making
nontrivial changes, prefer re-reading the local source over trusting the skill
text. In particular, do not assume `init.lua` still contains all `m`-family
logic; matching/surround behavior now has its own `helix/match.lua` module.

When the requested key comes from the user's Helix table, compare three layers:

- stock Helix behavior
- local overrides in `wrappers/helix.nix`
- existing Neovim behavior in `remaps.lua` and `helix/*.lua`

Local Helix overrides win over stock Helix. For example, this repo maps `H` and
`L` to previous/next buffer, and `g.k` to hover, even when those differ from
plain Vim expectations.

## Mental Model

The selection entry is the source of truth.

- Every selection entry stores `anchor_pos` and `cursor_pos`.
- `start_pos` and `end_pos` are normalized bounds derived from those two points.
- Newline is a first-class selectable cell in this Helix layer. On non-final
  lines, a valid cursor/selection column may be `#line + 1`, which means “the
  newline position”, not “past the end by mistake”.
- `position.lua` is the canonical home for newline-aware coordinate math:
  cursor max column, newline detection, boundary conversion, and next/previous
  positions. Do not hand-roll row/column math in other modules unless there is
  a very strong reason.
- The primary cursor is the real Neovim cursor.
- Secondary cursors and selection highlights are rendered from preview extmarks.
- Select mode and insert mode should both operate on the same local selection
  entries.

Current module intent:

- `position.lua`: newline-aware coordinate helpers
- `state.lua`: mode flags, preview state, and preview rendering
- `motion.lua`: movement semantics
- `match.lua`: `m` family matching, surround editing, and textobject behavior
- `insert.lua`: insert-session lifecycle
- `init.lua`: command wiring plus higher-level editing/search/surround helpers

Do not reintroduce plugin compatibility layers for multicursor behavior unless
the user explicitly asks for that.

## Implementation Workflow

1. Identify the Helix command name and behavior, not just the key text.
   Treat descriptions like `ms<char>` as generic placeholders, not literal
   characters.

2. Reuse the local selection helpers before adding new abstractions.
   Prefer helpers such as `selection_entry`, `current_entries`,
   `set_preview_entries`, `move_cursor_to_pos`, `entry_text_ranges`,
   `get_entry_text`, `replace_entry_text`, `getcharstr`, `feedkeys`, and the
   newline-aware position helpers in `position.lua`.

3. Preserve selection semantics explicitly.
   Helix commands usually act on selections. When implementing a motion or edit,
   decide where the anchor and cursor should land after the operation.

4. Preserve multi-selection behavior through local preview state.
   If a command should affect many selections, transform all selection entries
   together. Do not special-case a single real cursor path in ways that diverge
   from the multi-selection path unless the behavior is intentionally different.

5. For buffer edits touching many selections, snapshot extmarks first and apply
   edits from the end of the buffer backward.
   Do not edit one selection and then compute the next selection from shifted
   buffer positions.

6. For `c`, `d`, `i`, and related insert-driven operations, route through the
   local insert-session engine in `helix/insert.lua`.
   The current model is real Insert mode on the primary cursor with secondary
   synchronization driven from the local insert session state, not a blocking
   `getcharstr()` loop. Preserve live redraw while typing and preserve a single
   undo block for one insert session unless the user explicitly wants different
   behavior.

7. Keep changes narrowly scoped.
   Most Helix behavior changes should stay inside `remaps.lua` and
   `lua/axelcool1234/helix/`. Only touch `default.nix` if a real dependency is
   added or removed.

8. Treat newline-aware behavior as part of the feature, not a special-case hack.
   If a command works on ordinary characters in Helix, consider whether it must
   also work when the cursor or selection sits on the newline cell.

## Common Patterns

For simple Helix aliases backed by existing Neovim behavior, add a mapping with
a clear `desc` through the local `mappings` table.

For prompted Helix commands, prompt once and apply the result to all active
selection entries.

For regex-driven commands, prefer local Vim regex helpers such as
`vim.fn.matchstrpos` and preserve user options like `ignorecase`, `smartcase`,
and `magic`.

For cursor movement or selection math, prefer `position.lua` helpers such as
`cursor_max_column`, `supports_column`, `is_newline_pos`, `before_boundary`,
`after_boundary`, `next_pos`, and `prev_pos` rather than open-coding `#line`,
`+ 1`, or row/column clamps in the command implementation.

For newline-aware commands, treat the newline cell like selectable whitespace.
Examples:

- vertical motion may land on newline when the remembered column is past the end
  of a short line
- `d`, `c`, and `r` should work on newline positions and may join lines
- whole-line selections such as `x` should include the newline cell on
  non-final lines

For surround-like commands such as `ms<char>`, remember that `<char>` is the
typed delimiter. After inserting delimiters, update the active selection so the
anchor is on the opening delimiter and the cursor is on the closing delimiter
when that is Helix's behavior.

When surround edits can touch multiple selections on the same line, snapshot all
targets first and use temporary extmarks while applying edits from the end of
the buffer backward.

For clone-style commands such as `C` or `<A-c>`, preserve the original entries
and append cloned entries. Do not replace the original cursor set with only the
clones.

For whole-buffer selection, prefer populating local selection entries directly
instead of relying on Vim visual mode as the source of truth.

For vertical multicursor movement, preserve a remembered preferred column per
cursor. Do not let a short line permanently overwrite the desired target column.

## Headless Testing Strategy

Always run a headless Neovim smoke test after editing remaps or the local Helix
engine. Prefer `nix run .#neovim -- --headless ...` because it validates the
built wrapper, compiles Nix changes, and exercises the real startup path.

Important repo-specific note: the Nix-built Neovim wrapper only sees files that
are included in the Git source snapshot. If you add a new Lua file and the
wrapper cannot `require()` it, check whether it is still untracked. You do not
need to commit it, but you often do need to stage it so `nix run .#neovim` can
see it.

Preferred wrapper smoke shape:

```bash
nix run .#neovim -- --headless \
  '+lua print("wrapper-ok")' \
  +qa!
```

Test key registration by printing `maparg` descriptions:

```vim
+'lua for _, lhs in ipairs({ "c", "i", "d", "C", "%", "K", "<A-K>", "ms", "H", "L" }) do local m = vim.fn.maparg(lhs, "n", false, true); print(lhs .. " -> " .. (m.desc or m.rhs or "<callback>")) end'
```

Test behavior in scratch buffers, not just registration. Useful shapes:

```bash
nix run .#neovim -- --headless \
  "+lua vim.api.nvim_buf_set_lines(0, 0, -1, false, {'alpha beta alpha'})" \
  "+lua local helix = require('axelcool1234.helix'); helix.select_whole_buffer(); helix.select_regex_matches('alpha')" \
  "+lua local keys = vim.api.nvim_replace_termcodes('Z<Esc>', true, false, true); vim.api.nvim_feedkeys(keys, 'n', false); require('axelcool1234.helix').change_selection()" \
  "+lua print(vim.inspect(vim.api.nvim_buf_get_lines(0, 0, -1, false)))" \
  +qa!
```

```bash
nix run .#neovim -- --headless \
  "+lua local helix = require('axelcool1234.helix'); vim.api.nvim_buf_set_lines(0, 0, -1, false, {'a', 'a', 'a'}); vim.api.nvim_win_set_cursor(0, {1, 0}); helix.copy_selection_on_adjacent_line(1); helix.copy_selection_on_adjacent_line(1)" \
  "+lua local keys = vim.api.nvim_replace_termcodes('Z<Esc>', true, false, true); vim.api.nvim_feedkeys(keys, 'n', false); require('axelcool1234.helix').insert_mode()" \
  "+lua print(vim.inspect(vim.api.nvim_buf_get_lines(0, 0, -1, false)))" \
  +qa!
```

For undo-sensitive insert behavior, prefer testing on a real temporary file, not
an unnamed scratch buffer, because undo history is easier to observe reliably.
One insert session should normally roll back with a single `u`.

For a new motion, design at least one scratch-buffer check that proves the key's
observable behavior, such as cursor position, anchor/cursor direction,
selection text, clone count, buffer contents, or undo behavior.

Be careful with headless Insert mode tests that rely on `feedkeys()` timing.
They are useful as smoke checks, but they are not always a faithful proxy for
live UI insert behavior. Prefer direct helper validation or non-interactive
editing checks when possible.

For newline-aware behavior, prefer explicit scratch-buffer checks such as:

```bash
nix run .#neovim -- --headless \
  "+lua local helix = require('axelcool1234.helix'); vim.api.nvim_buf_set_lines(0, 0, -1, false, {'ab', 'cd'}); vim.api.nvim_win_set_cursor(0, {1, 2}); helix.delete(); print(vim.inspect(vim.api.nvim_buf_get_lines(0, 0, -1, false)))" \
  +qa!
```

That kind of check is more robust than trying to fully script a live Insert mode
session in headless Neovim.

Use and expand the local headless regression harness when possible:

- `wrappers/neovim/tests/match.lua`

Today that file focuses on the `m` family, but the harness structure itself is
general-purpose. When adding or fixing other Helix-style motions, prefer either:

- extending `wrappers/neovim/tests/match.lua` when the new cases still fit the
  same headless pattern, or
- creating a sibling harness file in `wrappers/neovim/tests/` that follows the
  same structure when the scope grows beyond matching/surround behavior

Preferred harness run shape:

```bash
nix run .#neovim -- --headless \
  '+doautocmd VimEnter' \
  "+lua dofile(vim.fn.getcwd() .. '/wrappers/neovim/tests/match.lua')" \
  +qa!
```

Harness files may intentionally include expected-error cases, so messages like
`Cursor on ambiguous surround pair` and `Surround pair not found around all
cursors` can appear during a successful run.

When possible, aggressively port cases from the Helix source tree instead of
inventing all tests from scratch. High-value upstream sources:

- `~/Projects/helix/helix-term/tests/test/movement.rs`
- `~/Projects/helix/helix-term/tests/test/commands.rs`
- `~/Projects/helix/helix-core/src/surround.rs`
- `~/Projects/helix/helix-core/src/match_brackets.rs`

Prefer copying the behavioral shape of an upstream Helix test into the local
harness, then adapting only the assertion format and cursor coordinates needed
for Neovim's API.

## Completion Checklist

- [ ] `wrappers/helix.nix` local overrides inspected
- [ ] `position.lua` newline-aware helpers inspected before changing row/col logic
- [ ] existing local Helix helpers reused where reasonable
- [ ] anchor/cursor landing behavior decided explicitly
- [ ] newline-cell behavior considered explicitly, not only ordinary characters
- [ ] local multi-selection behavior preserved without plugin compatibility
- [ ] extmark snapshot strategy used for multi-edit operations when needed
- [ ] current insert-session path considered for `c`/`d`/`i`-style changes
- [ ] headless Neovim load check passed
- [ ] key registration checked with `maparg`
- [ ] at least one scratch-buffer behavior check run for nontrivial motions
- [ ] undo behavior checked when insert semantics were changed
- [ ] a headless harness under `wrappers/neovim/tests/` updated or consciously checked when changing nontrivial Helix behavior
