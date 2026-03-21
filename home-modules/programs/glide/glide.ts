// Config docs:
//
//   https://glide-browser.app/config
//
// API reference:
//
//   https://glide-browser.app/api
//
// Default config files can be found here:
//
//   https://github.com/glide-browser/glide/tree/main/src/glide/browser/base/content/plugins
//
// Most default keymappings are defined here:
//
//   https://github.com/glide-browser/glide/blob/main/src/glide/browser/base/content/plugins/keymaps.mts
//
// Try typing `glide.` and see what you can do!

glide.prefs.set("layout.css.prefers-color-scheme.content-override", 0); // Force dark background for web content
glide.prefs.set("extensions.activeThemeID", "firefox-compact-dark@mozilla.org"); // Firefox default dark mode
// glide.prefs.set("general.smoothScroll", false);

glide.excmds.create({
  name: "nix",
  description: "Search NixOS packages on search.nixos.org",
}, async ({ args_arr }) => {
  const query = args_arr.join(" ").trim();

  const url = new URL("https://search.nixos.org/packages");
  url.searchParams.set("channel", "unstable");
  url.searchParams.set("query", query);

  await browser.tabs.create({ url: url.toString() });
  await glide.excmds.execute("keys <C-,>");
});

glide.keymaps.set("normal", "t", async () => {
  await glide.commandline.show({
    title: "Google Search",
    options: [
      {
        label: "Search Google",
        description: "Press Enter to search for the text you typed",
        matches() {
          return true;
        },
        async execute({ input }) {
          const query = input.trim();
          if (!query) {
            return;
          }

          await browser.tabs.create({
            url: `https://www.google.com/search?q=${encodeURIComponent(query)}`,
          });
        },
      },
    ],
  });
}, { description: "Search Google" });

glide.keymaps.set(
  "normal",
  "<C-w>v",
  async ({ tab_id }) => {
    const all_tabs = await glide.tabs.query({});
    const current_index = all_tabs.findIndex((t) =>
      t.id === tab_id
    );
    const other = all_tabs[current_index + 1];
    if (!other) {
      throw new Error("No next tab");
    }
    glide.unstable.split_views.create([tab_id, other]);
  },
  {
    description:
      "Create a split view with the tab to the right",
  },
);

glide.keymaps.set(
  "normal",
  "<C-w>q",
  async ({ tab_id }) => {
    glide.unstable.split_views.separate(tab_id);
  },
  {
    description: "Close the split view for the current tab",
  },
);

glide.keymaps.set("normal", "H", "tab_prev");
glide.keymaps.set("normal", "L", "tab_next");
glide.keymaps.set("normal", "gq", "tab_close");

glide.keymaps.set("normal", "J", "back");
glide.keymaps.set("normal", "K", "forward");

glide.keymaps.set("normal", "<C-d>", "scroll_page_down");
glide.keymaps.set("normal", "<C-u>", "scroll_page_up");
glide.keymaps.set("normal", "ge", "scroll_bottom");

glide.keymaps.set("normal", "<C-f>", "hint --location=browser-ui");
glide.keymaps.set("normal", "<leader>f", "commandline_show tab ");
glide.keymaps.set("normal", "/", () => {
  glide.findbar.open();
}, { description: "search"});

glide.keymaps.set("normal", "gl", "keys $");
glide.keymaps.set("normal", "gh", "keys ^");
