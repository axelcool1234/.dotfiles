import assert from "node:assert/strict";
import childProcess from "node:child_process";
import { syncBuiltinESMExports } from "node:module";
import { afterEach, mock, test } from "node:test";
import extension from "../extensions/jjui.ts";

afterEach(() => {
  mock.restoreAll();
  syncBuiltinESMExports();
});

function setup(result = { status: 0, signal: null }, mode = "tui") {
  const events = [];
  const shortcuts = new Map();
  const commands = new Map();
  extension({
    registerShortcut: (key, options) => shortcuts.set(key, options),
    registerCommand: (name, options) => commands.set(name, options),
  });
  const spawn = mock.method(childProcess, "spawnSync", (...args) => {
    events.push(["spawn", ...args]);
    if (result instanceof Error) throw result;
    return result;
  });
  syncBuiltinESMExports();
  const ctx = {
    mode,
    cwd: "/some project/nested directory",
    ui: {
      notify: (...args) => events.push(["notify", ...args]),
      custom: (factory) => new Promise((resolve) => {
        // Do not emit terminal escape sequences into the test runner's output.
        const write = mock.method(process.stdout, "write", (data) => {
          events.push(["write", data]);
          return true;
        });
        try {
          const component = factory({
            stop: () => events.push(["stop"]),
            start: () => events.push(["start"]),
            requestRender: (force) => events.push(["render", force]),
          }, {}, {}, (value) => {
            events.push(["done", value]);
            resolve(value);
          });
          assert.deepEqual(component.render(80), []);
          component.invalidate();
        } finally {
          write.mock.restore();
        }
      }),
    },
  };
  return { shortcuts, commands, ctx, events, spawn };
}

test("Ctrl+j launches jjui with inherited terminal in ctx.cwd and restores Pi", async () => {
  const { shortcuts, commands, ctx, events } = setup();
  assert.deepEqual([...shortcuts.keys()], ["ctrl+j"]);
  assert.deepEqual([...commands.keys()], ["jjui"]);
  await shortcuts.get("ctrl+j").handler(ctx);
  assert.deepEqual(events, [
    ["stop"],
    ["write", "\x1b[2J\x1b[H"],
    ["spawn", "jjui", [], { cwd: ctx.cwd, stdio: "inherit" }],
    ["start"],
    ["render", true],
    ["done", undefined],
  ]);
});

test("/jjui uses the same launcher", async () => {
  const { commands, ctx, spawn } = setup();
  await commands.get("jjui").handler("", ctx);
  assert.equal(spawn.mock.callCount(), 1);
});

for (const [name, result, message] of [
  ["missing executable", { error: new Error("spawnSync jjui ENOENT") }, "Could not launch jjui: spawnSync jjui ENOENT"],
  ["nonzero exit", { status: 1 }, "jjui exited with code 1"],
  ["signal exit", { status: null, signal: "SIGTERM" }, "jjui terminated by SIGTERM"],
  ["unknown exit", { status: null }, "jjui exited with code unknown"],
  ["thrown exception", new Error("spawn failed"), "Could not launch jjui: spawn failed"],
]) {
  test(`${name} restores Pi before reporting an error`, async () => {
    const { shortcuts, ctx, events } = setup(result);
    await shortcuts.get("ctrl+j").handler(ctx);
    assert.deepEqual(events.slice(-4), [
      ["start"], ["render", true], ["done", message], ["notify", message, "error"],
    ]);
  });
}

for (const mode of ["rpc", "print", "json"]) {
  test(`${mode} mode never takes over the terminal`, async () => {
    const { commands, ctx, events, spawn } = setup(undefined, mode);
    await commands.get("jjui").handler("", ctx);
    assert.equal(spawn.mock.callCount(), 0);
    assert.deepEqual(events, [["notify", "jjui requires Pi's interactive terminal mode", "error"]]);
  });
}
