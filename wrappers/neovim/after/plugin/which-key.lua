-- Keep which-key instant, but leave enough timeout for builtin-prefix mappings
-- like `m` to resolve to longer custom bindings instead of the builtin command.
vim.o.timeoutlen = 300

-- Load and configure which-key.nvim
local wk = require("which-key")
local wk_plugins = require("which-key.plugins")
local manual_triggers = _G.axelcool1234_which_key_triggers or {}
local triggers = { { "<auto>", mode = "nixsotc" } }
vim.list_extend(triggers, manual_triggers)

wk.setup({
  preset = "helix",
  delay = 0,
  sort = { "manual", "local", "group", "alphanum", "mod" },
  plugins = {
    registers = false,
    presets = {
      operators = true,
      motions = true,
      text_objects = true,
      windows = false,
      nav = true,
      z = true,
      g = false,
    },
  },
  triggers = triggers,
  win = {
    no_overlap = false,
  },
})

wk_plugins.plugins.helix_registers = {
  name = "helix_registers",
  mappings = {
    { '"', mode = "n", desc = "Select register", plugin = "helix_registers" },
  },
  expand = function()
    return require("axelcool1234.helix").which_key_register_items()
  end,
}

wk_plugins._setup(wk_plugins.plugins.helix_registers, { enabled = true })
