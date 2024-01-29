-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
vim.opt.tabstop = 4 -- Number of spaces tab count for
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4 -- Size of an indent

-- Vimtex --
vim.g.vimtex_view_method = "zathura"
vim.g.vimtex_compiler_latexmk = {
    executable = "latexmk",
    options = {
        "-synctex=1",
        "-interaction=nonstopmode",
        "-file-line-error",
    },
    out_dir = "build",
}
