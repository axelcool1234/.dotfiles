if vim.env.NVIM_ENABLE_NOCTALIA_THEME ~= "1" then
  return
end

local uv = vim.uv or vim.loop
local palette_path = vim.fn.expand("~/.cache/noctalia/nvim-base16.lua")
local signal = nil

local function apply_noctalia_palette()
  if not uv.fs_stat(palette_path) then
    return
  end

  local palette_ok, palette = pcall(dofile, palette_path)
  if not palette_ok then
    vim.notify(
      ("Noctalia palette could not be loaded from %s: %s"):format(palette_path, palette),
      vim.log.levels.WARN
    )
    return
  end

  local base16_ok, base16 = pcall(require, "base16-colorscheme")
  if not base16_ok then
    vim.notify(
      ("base16-colorscheme is unavailable: %s"):format(base16),
      vim.log.levels.ERROR
    )
    return
  end

  base16.setup(palette)

  -- Trigger standard colorscheme listeners plus a Noctalia-specific hook so UI
  -- plugins can rebuild any cached highlights after the generated palette lands.
  vim.api.nvim_exec_autocmds("ColorScheme", {
    modeline = false,
    pattern = "noctalia-base16",
  })
  vim.api.nvim_exec_autocmds("User", {
    modeline = false,
    pattern = "NoctaliaThemeReloaded",
  })
end

apply_noctalia_palette()

signal = uv.new_signal()
if signal then
  signal:start("sigusr1", vim.schedule_wrap(apply_noctalia_palette))

  vim.api.nvim_create_autocmd("VimLeavePre", {
    callback = function()
      if signal:is_closing() then
        return
      end

      signal:stop()
      signal:close()
    end,
  })
end
