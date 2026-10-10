local position = require("axelcool1234.helix.position")

local M = {}

function M.upper(text)
  return vim.fn.toupper((text:gsub("ß", "SS")))
end

function M.lower(text)
  return vim.fn.tolower((text:gsub("İ", "i̇")))
end

function M.toggle(text)
  local toggled = {}
  for col = 1, position.grapheme_count(text) do
    local grapheme = position.grapheme_at(text, col)
    local lower, upper = M.lower(grapheme), M.upper(grapheme)
    toggled[#toggled + 1] = grapheme == lower and grapheme ~= upper and upper or (grapheme == upper and grapheme ~= lower and lower or grapheme)
  end
  return table.concat(toggled)
end

return M
