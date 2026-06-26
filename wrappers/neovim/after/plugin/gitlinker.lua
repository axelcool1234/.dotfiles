require("gitlinker").setup({
  mappings = nil,
})

pcall(vim.keymap.del, "n", "<leader>gy")
pcall(vim.keymap.del, "v", "<leader>gy")
