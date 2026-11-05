import { spawnSync } from "node:child_process";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  const launch = async (ctx: ExtensionContext) => {
    if (ctx.mode !== "tui") {
      ctx.ui.notify("jjui requires Pi's interactive terminal mode", "error");
      return;
    }

    // Follow Pi's interactive-shell example: release the terminal while jjui
    // runs, then restore Pi without changing the editor or conversation.
    const failure = await ctx.ui.custom<string | undefined>((tui, _theme, _keys, done) => {
      let failure: string | undefined;
      tui.stop();
      try {
        process.stdout.write("\x1b[2J\x1b[H");
        const result = spawnSync("jjui", [], { cwd: ctx.cwd, stdio: "inherit" });
        if (result.error) {
          failure = `Could not launch jjui: ${result.error.message}`;
        } else if (result.signal) {
          failure = `jjui terminated by ${result.signal}`;
        } else if (result.status !== 0) {
          failure = `jjui exited with code ${result.status ?? "unknown"}`;
        }
      } catch (error) {
        failure = `Could not launch jjui: ${error instanceof Error ? error.message : String(error)}`;
      } finally {
        tui.start();
        tui.requestRender(true);
      }
      done(failure);
      return { render: () => [], invalidate() {} };
    });

    if (failure) ctx.ui.notify(failure, "error");
  };

  pi.registerShortcut("ctrl+j", {
    description: "Open jjui in the current directory",
    handler: launch,
  });
  pi.registerCommand("jjui", {
    description: "Open jjui in the current directory",
    handler: async (_args, ctx) => launch(ctx),
  });
}
