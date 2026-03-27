require('telescope').setup({
  defaults = {
    prompt_prefix = " ",
    selection_caret = " ",
    find_command = function()
      if vim.fn.executable("rg") == 1 then
        return { "rg", "--files", "--color", "never", "-g", "!.git" }
      elseif vim.fn.executable("fd") == 1 then
        return { "fd", "--type", "f", "--color", "never", "-E", ".git" }
      elseif vim.fn.executable("fdfind") == 1 then
        return { "fdfind", "--type", "f", "--color", "never", "-E", ".git" }
      elseif vim.fn.executable("find") == 1 and vim.fn.has("win32") == 0 then
        return { "find", ".", "-type", "f" }
      elseif vim.fn.executable("where") == 1 then
        return { "where", "/r", ".", "*" }
      end
    end,
  },
  pickers = {
    find_files = {
      find_command = { "rg", "--files", "--color", "never", "-g", "!.git" },  -- Default to ripgrep if available
      hidden = true,
    },
  },
})
require('telescope').load_extension('fzf')
