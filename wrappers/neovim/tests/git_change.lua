require("axelcool1234")
require("axelcool1234.remaps")
vim.cmd.runtime("after/plugin/gitsigns.lua")

local helix = require("axelcool1234.helix")
local cache = require("gitsigns.cache").cache
local root = vim.fn.tempname()
local file = root .. "/append_assoc.lean"
local original = {
  "theorem append_assoc {α : Type} {l₁ l₂ l₃ : List α} :",
  "    l₁ ++ l₂ ++ l₃ = l₁ ++ (l₂ ++ l₃) := by",
  "  sorry",
  "",
  "-- unchanged separator",
  "def answer := 0",
}
local changed = {
  original[1],
  original[2],
  "  induction l₁ with",
  "  | nil => rfl",
  "  | cons h t ih =>",
  "    rw [List.cons_append, List.cons_append, List.cons_append, ih]",
  original[4],
  original[5],
  "def answer := 42",
}
local proof = table.concat(vim.list_slice(changed, 3, 6), "\n") .. "\n"

local function assert_equal(actual, expected, label)
  if not vim.deep_equal(actual, expected) then
    error(label .. "\nexpected: " .. vim.inspect(expected) .. "\nactual:   " .. vim.inspect(actual))
  end
end

local function keys(sequence)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(sequence, true, false, true), "xt", false)
end

local function assert_selection(text, label)
  assert_equal(helix.primary_range():text(), text, label)
  local ns = vim.api.nvim_get_namespaces()["axelcool1234-helix-selection"]
  local highlights = vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, { details = true })
  assert_equal(#highlights, 1, label .. " should render one highlight")
  local mark = highlights[1]
  local rendered = vim.api.nvim_buf_get_text(0, mark[2], mark[3], mark[4].end_row, mark[4].end_col, {})
  assert_equal(table.concat(rendered, "\n"), text, label .. " should highlight the complete selection")
end

vim.fn.mkdir(root, "p")
local bufnr
local ok, err = xpcall(function()
  vim.fn.writefile(original, file)
  for _, args in ipairs({ { "init", "--quiet", root }, { "-C", root, "add", "append_assoc.lean" } }) do
    local result = vim.system(vim.list_extend({ "git" }, args), { text = true }):wait()
    assert_equal(result.code, 0, "temporary repository setup: " .. (result.stderr or ""))
  end

  vim.cmd("edit " .. vim.fn.fnameescape(file))
  bufnr = vim.api.nvim_get_current_buf()
  -- Avoid Lean LSP startup; this fixture exercises Git and selections only.
  vim.bo.filetype = "text"
  require("gitsigns").attach(bufnr)
  assert(vim.wait(5000, function()
    return cache[bufnr] and cache[bufnr].hunks ~= nil
  end, 10), "gitsigns should attach to the indexed Lean fixture")

  -- Keep the replacement unsaved so the test also covers buffer updates.
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, changed)
  assert(vim.wait(5000, function()
    local hunks = cache[bufnr] and cache[bufnr].hunks
    return hunks and #hunks > 0
  end, 10), "gitsigns should detect the replacement")

  keys("gg")
  keys("]g")
  assert_selection(proof, "]g should select the entire Lean replacement")
  assert_equal(helix.primary_range():direction(), 1, "]g should select forward")
  keys("]g")
  assert_selection(changed[9], "]g should advance to a separate change")
  keys("[g")
  assert_selection(proof, "[g should select the entire previous replacement")
  assert_equal(helix.primary_range():direction(), -1, "[g should select backward")

  for _, row in ipairs({ 3, 5, 6 }) do
    keys("<Esc>")
    keys(row .. "gg")
    keys("mag")
    assert_selection(proof, "mag should select the same hunk from row " .. row)
  end

  keys("<Esc>")
  keys("ggv]g")
  assert_selection(table.concat(vim.list_slice(changed, 1, 6), "\n") .. "\n",
    "]g in select mode should extend through the entire replacement")
end, debug.traceback)

keys("<Esc>")
if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
  require("gitsigns").detach(bufnr)
  vim.api.nvim_buf_delete(bufnr, { force = true })
end
vim.fn.delete(root, "rf")
if not ok then
  error(err)
end
print("git-change-tests-ok")
