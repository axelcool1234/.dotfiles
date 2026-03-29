vim.opt.termguicolors = true

local bufferline_config = {
  options = {
    style_preset = require("bufferline").style_preset.minimal,
  },
}

local function get_highlight(name)
  local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
  if ok then
    return hl
  end

  return nil
end

local function list_bufferline_highlights()
  local names = vim.fn.getcompletion("BufferLine", "highlight")
  names[#names + 1] = "TabLine"
  names[#names + 1] = "TabLineFill"
  names[#names + 1] = "TabLineSel"
  return names
end

local function should_flatten_separator(name)
  return name:find("Separator", 1, true) ~= nil or name == "BufferLineFill"
end

local function is_selected_group(name)
  return name == "TabLineSel" or name:find("Selected", 1, true) ~= nil
end

local function is_visible_group(name)
  return name == "TabLine" or name:find("Visible", 1, true) ~= nil
end

local function normalize_bufferline_highlights()
  local normal = get_highlight("Normal")
  if not normal or not normal.bg or not normal.fg then
    return
  end

  local comment = get_highlight("Comment") or {}
  local tabline_selected = get_highlight("TabLineSel") or {}
  local inactive_fg = comment.fg or normal.fg
  local visible_fg = normal.fg
  local selected_fg = tabline_selected.fg or normal.fg

  for _, name in ipairs(list_bufferline_highlights()) do
    local hl = get_highlight(name)
    if hl then
      hl.bg = normal.bg

      if should_flatten_separator(name) then
        hl.fg = normal.bg
      elseif is_selected_group(name) then
        hl.fg = selected_fg
      elseif is_visible_group(name) then
        hl.fg = visible_fg
      else
        hl.fg = inactive_fg
      end

      hl.link = nil
      hl.default = nil
      vim.api.nvim_set_hl(0, name, hl)
    end
  end
end

local function setup_bufferline()
  require("bufferline").setup(bufferline_config)
  normalize_bufferline_highlights()
end

setup_bufferline()

vim.api.nvim_create_autocmd("User", {
  pattern = "NoctaliaThemeReloaded",
  callback = function()
    setup_bufferline()
    vim.cmd("redrawtabline")
  end,
})
