{
  config,
  inputs,
  pkgs,
  wlib,
  system,
  ...
}:
let
  mkExtension = shortId: uuid: {
    name = uuid;
    value = {
      install_url = "https://addons.mozilla.org/en-US/firefox/downloads/latest/${shortId}/latest.xpi";
      installation_mode = "normal_installed";
    };
  };

  glidePackage = pkgs.wrapFirefox (
    inputs.glide.packages.${system}.glide-browser-bin-unwrapped.override {
      policies = {
        ExtensionSettings = builtins.listToAttrs [
          (mkExtension "ublock-origin" "uBlock0@raymondhill.net")
          (mkExtension "adaptive-tab-bar-colour" "ATBC@EasonWong")
          (mkExtension "view-page-archive" "{d07ccf11-c0cd-4938-a265-2a4d6ad01189}")
        ];
      };
    }
  ) {
    pname = "glide-browser";
  };
in
{
  imports = [ wlib.modules.default ];

  config = {
    package = glidePackage;

    escapingFunction = wlib.escapeShellArgWithEnv;

    env = {
      GLIDE_PROFILE_DIR = "${"$"}{XDG_STATE_HOME:-${"$"}HOME/.local/state}/glide-browser/profile";
    };

    flags = {
      "--profile" = "$GLIDE_PROFILE_DIR";
    };

    runShell = [
      ''mkdir -p "$GLIDE_PROFILE_DIR/glide"''
      ''if [ ! -e "$GLIDE_PROFILE_DIR/glide/glide.ts" ]; then cp ${config.constructFiles.glideTs.path} "$GLIDE_PROFILE_DIR/glide/glide.ts"; fi''
    ];

    constructFiles.glideTs = {
      relPath = "glide/glide.ts";
      content = /* typescript */ ''
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

        glide.prefs.set("layout.css.prefers-color-scheme.content-override", 0);
        glide.prefs.set("extensions.activeThemeID", "firefox-compact-dark@mozilla.org");

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
                    url: `https://www.google.com/search?q=''${encodeURIComponent(query)}`,
                  });
                },
              },
            ],
          });
        }, { description: "Search Google" });

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
      '';
      builder = ''mkdir -p "$(dirname "$2")" && cp "$1" "$2"'';
    };
  };
}
