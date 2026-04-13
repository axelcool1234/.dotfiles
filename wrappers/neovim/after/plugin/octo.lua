require("octo").setup({
  picker = "telescope",
  enable_builtin = true,
  mappings_disable_default = true,
  -- Octo clears most default mapping groups when `mappings_disable_default`
  -- is true, but currently forgets `runs` and `notification`. Parts of Octo's
  -- picker stack assume those tables still exist and index fields like
  -- `cfg.mappings.notification.read.lhs`, so we keep these definitions here as
  -- a compatibility workaround while owning the actual review/PR mappings
  -- ourselves elsewhere.
  mappings = {
    runs = {
      expand_step = { lhs = "o", desc = "expand workflow step" },
      open_in_browser = { lhs = "<C-b>", desc = "open workflow run in browser" },
      refresh = { lhs = "<C-r>", desc = "refresh workflow" },
      rerun = { lhs = "<C-o>", desc = "rerun workflow" },
      rerun_failed = { lhs = "<C-f>", desc = "rerun failed workflow" },
      cancel = { lhs = "<C-x>", desc = "cancel workflow" },
      copy_url = { lhs = "<C-y>", desc = "copy url to system clipboard" },
    },
    notification = {
      read = { lhs = "<localleader>nr", desc = "mark notification as read" },
      done = { lhs = "<localleader>nd", desc = "mark notification as done" },
      unsubscribe = { lhs = "<localleader>nu", desc = "unsubscribe from notifications" },
    },
  },
})

require("axelcool1234.helix.octo").setup()
