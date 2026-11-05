# Pi

## Shortcuts

- **Ctrl+j** or **`/jjui`** opens the wrapped `jjui` in Pi's current directory.
  Quit jjui normally to return to the same Pi session and editor draft.
- Ctrl+j replaces Pi's default newline shortcut; **Shift+Enter** still inserts a
  newline. The launcher is available only in interactive terminal mode.

The extension is loaded through the wrapper's generated `settings.extensions`,
and the wrapper supplies `jjui` on `PATH`. Rebuild/activate the Pi wrapper, then
start Pi again to synchronize the new settings. For a one-off test before
activation, run from the repository root:

```sh
pi -e ./wrappers/pi/extensions/jjui.ts
```

## Advisor

`default.nix` declares `openai-codex/gpt-6.1-sol` with `high` reasoning in a
separate `advisor.json`. Same-model consultations are explicitly allowed;
otherwise the plugin skips reviews when the Executor uses that model too.
This does not pin or change the Executor model.

On wrapper startup, the declared Advisor values are merged into the writable
agent directory (normally `~/.pi/agent`), preserving undeclared preferences.
Rebuild/activate the wrapper and restart Pi to apply changes.

## Tests

Launcher regression tests (Node.js 24+):

```sh
node --test wrappers/pi/tests/jjui.test.mjs
```

Writable configuration integration tests:

```sh
nix build .#pi
python wrappers/pi/tests/sync-config.py ./result
```
