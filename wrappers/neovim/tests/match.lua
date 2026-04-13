local helix = require("axelcool1234.helix")

local function feed(keys)
  local termcodes = vim.api.nvim_replace_termcodes(keys, true, false, true)
  vim.api.nvim_feedkeys(termcodes, "xt", false)
  vim.wait(150)
end

local function run_keys(sequence)
  if type(sequence) == "string" then
    feed(sequence)
    return
  end

  for _, keys in ipairs(sequence) do
    feed(keys)
  end
end

local function selection_texts()
  local ns = vim.api.nvim_get_namespaces()["axelcool1234-helix-selection"]
  if not ns then
    return {}
  end

  local texts = {}
  for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, { details = true })) do
    local pieces = vim.api.nvim_buf_get_text(0, mark[2], mark[3], mark[4].end_row, mark[4].end_col, {})
    texts[#texts + 1] = table.concat(pieces, "\n")
  end

  return texts
end

local function secondary_cursor_count()
  local ns = vim.api.nvim_get_namespaces()["axelcool1234-helix-cursor"]
  if not ns then
    return 0
  end

  return #vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, {})
end

local function reset_case(lines, filetype, row, col0)
  vim.cmd("enew!")
  vim.bo.filetype = filetype or "text"
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  if filetype and filetype ~= "text" then
    pcall(vim.treesitter.start, 0)
  end
  vim.api.nvim_win_set_cursor(0, { row, col0 })
end

local function assert_equal(actual, expected, label)
  if not vim.deep_equal(actual, expected) then
    error(label .. "\nexpected: " .. vim.inspect(expected) .. "\nactual:   " .. vim.inspect(actual))
  end
end

local function current_lines()
  return vim.api.nvim_buf_get_lines(0, 0, -1, false)
end

local cases = {
  {
    name = "mim between quoted segments no-op",
    run = function()
      reset_case({ "- Figure out `direnv` + `lorri` and add support" }, "text", 1, 22)
      run_keys("mim")
      assert_equal(selection_texts(), {}, "mim should not select between quote pairs")
      assert_equal(vim.api.nvim_win_get_cursor(0), { 1, 22 }, "cursor should stay put")
    end,
  },
  {
    name = "explicit same-char selects across separator",
    run = function()
      reset_case({ "- Figure out `direnv` + `lorri` and add support" }, "text", 1, 22)
      run_keys("mi`")
      assert_equal(selection_texts(), { " + " }, "mi` should select text between surrounding backticks")
    end,
  },
  {
    name = "mam climbs from quotes to brackets",
    run = function()
      reset_case({ '  { "File picker", "<leader>f", find_files, "n" },' }, "lua", 1, 7)
      run_keys("mam")
      assert_equal(selection_texts(), { '"File picker"' }, "first mam should select quotes")
      run_keys("mam")
      assert_equal(selection_texts(), { '{ "File picker", "<leader>f", find_files, "n" }' }, "second mam should select braces")
    end,
  },
  {
    name = "mi explicit paren selects inner text",
    run = function()
      reset_case({ "some (text) here" }, "text", 1, 7)
      run_keys("mi(")
      assert_equal(selection_texts(), { "text" }, "mi( should select inside parens")
    end,
  },
  {
    name = "ma explicit paren selects pair",
    run = function()
      reset_case({ "some (text) here" }, "text", 1, 7)
      run_keys("ma(")
      assert_equal(selection_texts(), { "(text)" }, "ma( should select around parens")
    end,
  },
  {
    name = "mam no-op when no outer pair",
    run = function()
      reset_case({ "- Figure out `direnv` + `lorri` and add support" }, "text", 1, 15)
      run_keys("mam")
      assert_equal(selection_texts(), { "`direnv`" }, "first mam should select local pair")
      run_keys("mam")
      assert_equal(selection_texts(), { "`direnv`" }, "second mam should leave selection intact")
    end,
  },
  {
    name = "mim nested counts",
    run = function()
      local line = "(so (many (good) text) here)"
      reset_case({ line }, "text", 1, 12)
      run_keys("1mim")
      assert_equal(selection_texts(), { "good" }, "1mim should select innermost contents")
      reset_case({ line }, "text", 1, 12)
      run_keys("2mim")
      assert_equal(selection_texts(), { "many (good) text" }, "2mim should select next outer contents")
      reset_case({ line }, "text", 1, 12)
      run_keys("3mim")
      assert_equal(selection_texts(), { "so (many (good) text) here" }, "3mim should select outermost contents")
    end,
  },
  {
    name = "mam nested counts",
    run = function()
      local line = "(so (many (good) text) here)"
      reset_case({ line }, "text", 1, 12)
      run_keys("1mam")
      assert_equal(selection_texts(), { "(good)" }, "1mam should select innermost pair")
      reset_case({ line }, "text", 1, 12)
      run_keys("2mam")
      assert_equal(selection_texts(), { "(many (good) text)" }, "2mam should select next outer pair")
      reset_case({ line }, "text", 1, 12)
      run_keys("3mam")
      assert_equal(selection_texts(), { "(so (many (good) text) here)" }, "3mam should select outermost pair")
    end,
  },
  {
    name = "mim mixed braces counts",
    run = function()
      local line = "(so [many {good} text] here)"
      reset_case({ line }, "text", 1, 12)
      run_keys("1mim")
      assert_equal(selection_texts(), { "good" }, "1mim should select inner mixed contents")
      reset_case({ line }, "text", 1, 12)
      run_keys("2mim")
      assert_equal(selection_texts(), { "many {good} text" }, "2mim should select bracket contents")
      reset_case({ line }, "text", 1, 12)
      run_keys("3mim")
      assert_equal(selection_texts(), { "so [many {good} text] here" }, "3mim should select paren contents")
    end,
  },
  {
    name = "mdm deletes nearest quoted pair",
    run = function()
      reset_case({ "- Figure out `direnv` + `lorri` and add the needed support" }, "text", 1, 17)
      run_keys("mdm")
      assert_equal(current_lines(), { "- Figure out direnv + `lorri` and add the needed support" }, "mdm should delete nearest backtick pair")
    end,
  },
  {
    name = "md explicit deletes explicit pair",
    run = function()
      reset_case({ "some (text) here" }, "text", 1, 7)
      run_keys("md(")
      assert_equal(current_lines(), { "some text here" }, "md( should delete explicit pair")
    end,
  },
  {
    name = "2mdm deletes enclosing pair",
    run = function()
      reset_case({ "- Figure out [`direnv`] + `lorri` and add the needed support" }, "text", 1, 18)
      run_keys("2mdm")
      assert_equal(current_lines(), { "- Figure out `direnv` + `lorri` and add the needed support" }, "2mdm should delete outer enclosing pair")
    end,
  },
  {
    name = "md explicit ambiguous no-op",
    run = function()
      reset_case({ "some `text` here" }, "text", 1, 5)
      run_keys("md`")
      assert_equal(current_lines(), { "some `text` here" }, "md` should not edit on ambiguous cursor")
    end,
  },
  {
    name = "mr nearest replaces nearest pair",
    run = function()
      reset_case({ "some (text) here" }, "text", 1, 7)
      run_keys("mrm[")
      assert_equal(current_lines(), { "some [text] here" }, "mrm should replace nearest pair")
    end,
  },
  {
    name = "mr explicit replaces explicit pair",
    run = function()
      reset_case({ "some (text) here" }, "text", 1, 7)
      run_keys("mr([")
      assert_equal(current_lines(), { "some [text] here" }, "mr( [ should replace explicit pair")
    end,
  },
  {
    name = "mrm counted outer replacement",
    run = function()
      reset_case({ 'fn main() { let _ = (("123", "123")); } ' }, "rust", 1, 24)
      run_keys("2mrm{")
      assert_equal(current_lines(), { 'fn main() { let _ = ({"123", "123"}); } ' }, "2mrm{ should replace next outer pair")
    end,
  },
  {
    name = "mi explicit ambiguous no-op",
    run = function()
      reset_case({ "some `text` here" }, "text", 1, 5)
      run_keys("mi`")
      assert_equal(selection_texts(), {}, "mi` should not select when cursor is on ambiguous delimiter")
    end,
  },
  {
    name = "mim no-op without surrounding pair",
    run = function()
      reset_case({ "some text here" }, "text", 1, 7)
      run_keys("mim")
      assert_equal(selection_texts(), {}, "mim should do nothing without a pair")
    end,
  },
  {
    name = "maw no-op on separating whitespace",
    run = function()
      reset_case({ "- Replace recorder script" }, "text", 1, 1)
      run_keys("maw")
      assert_equal(selection_texts(), {}, "maw should not select punctuation-adjacent whitespace")
    end,
  },
  {
    name = "maw prefers trailing whitespace on word",
    run = function()
      reset_case({ "- Replace recorder script" }, "text", 1, 2)
      run_keys("maw")
      assert_equal(selection_texts(), { "Replace " }, "maw should include trailing whitespace when available")
    end,
  },
  {
    name = "miw selects word only",
    run = function()
      reset_case({ "- Replace recorder script" }, "text", 1, 2)
      run_keys("miw")
      assert_equal(selection_texts(), { "Replace" }, "miw should select the word without surrounding whitespace")
    end,
  },
  {
    name = "maf and mif use function textobject",
    run = function()
      reset_case({ "local function f(a, b)", "  return a + b", "end" }, "lua", 2, 4)
      run_keys("maf")
      assert_equal(selection_texts(), { "local function f(a, b)\n  return a + b\nend" }, "maf should select around the function")
      reset_case({ "local function f(a, b)", "  return a + b", "end" }, "lua", 2, 4)
      run_keys("mif")
      assert_equal(selection_texts(), { "return a + b" }, "mif should select inside the function")
    end,
  },
  {
    name = "maa and mia use parameter textobject",
    run = function()
      reset_case({ "local function f(a, b)", "  return a + b", "end" }, "lua", 1, 17)
      run_keys("maa")
      assert_equal(selection_texts(), { "a" }, "maa should select the parameter around the cursor")
      reset_case({ "local function f(a, b)", "  return a + b", "end" }, "lua", 1, 17)
      run_keys("mia")
      assert_equal(selection_texts(), { "a" }, "mia should select inside the parameter")
    end,
  },
  {
    name = "mac and mic use comment textobject",
    run = function()
      reset_case({ "-- hello world" }, "lua", 1, 3)
      run_keys("mac")
      assert_equal(selection_texts(), { "-- hello world" }, "mac should select around the comment")
      reset_case({ "-- hello world" }, "lua", 1, 3)
      run_keys("mic")
      assert_equal(selection_texts(), { "-- hello world" }, "mic should select inside the comment per current query")
    end,
  },
  {
    name = "mae and mie use entry textobject",
    run = function()
      reset_case({ "local x = { a = 1, b = 2 }" }, "lua", 1, 16)
      run_keys("mae")
      assert_equal(selection_texts(), { "a = 1" }, "mae should select around the table entry")
      reset_case({ "local x = { a = 1, b = 2 }" }, "lua", 1, 16)
      run_keys("mie")
      assert_equal(selection_texts(), { "1" }, "mie should select inside the table entry")
    end,
  },
  {
    name = "mai and mii use indentation level textobject",
    run = function()
      reset_case({
        "if foo then",
        "  if bar then",
        "    baz()",
        "    qux()",
        "  end",
        "end",
      }, "lua", 3, 4)
      run_keys("mai")
      assert_equal(selection_texts(), { "    baz()\n    qux()" }, "mai should select the current indentation block")

      reset_case({
        "if foo then",
        "  if bar then",
        "    baz()",
        "    qux()",
        "  end",
        "end",
      }, "lua", 3, 4)
      run_keys("mii")
      assert_equal(selection_texts(), { "    baz()\n    qux()" }, "mii should select inside the current indentation block")
    end,
  },
  {
    name = "mii respects markdown two-space list indentation",
    run = function()
      reset_case({
        "- Improve Kitty",
        "  - Scratchpads",
        "  - Motion that yanks filepaths and urls",
        "  - Look into whether or not a Tmux vim mode where you can move around is possible, or",
        "    if CTRL+SHIFT+E to explore the scrollback is all we can do",
      }, "markdown", 2, 4)
      run_keys("mii")
      assert_equal(selection_texts(), {
        "  - Scratchpads\n  - Motion that yanks filepaths and urls\n  - Look into whether or not a Tmux vim mode where you can move around is possible, or\n    if CTRL+SHIFT+E to explore the scrollback is all we can do"
      }, "mii should select the inner markdown list items instead of the whole document")
    end,
  },
  {
    name = "mag selects whole hunk",
    run = function()
      reset_case({ "one", "two", "three", "four" }, "text", 2, 1)
      local cache = require("gitsigns.cache").cache
      local bufnr = vim.api.nvim_get_current_buf()
      cache[bufnr] = {
        get_hunks = function()
          return {
            {
              added = { start = 2, count = 2 },
              vend = 3,
            },
          }
        end,
      }
      run_keys("mag")
      assert_equal(selection_texts(), { "two\nthree\n" }, "mag should select the entire hunk, not just the current line")
      cache[bufnr] = nil
    end,
  },
  {
    name = "mam no-op without surrounding pair",
    run = function()
      reset_case({ "some text here" }, "text", 1, 7)
      run_keys("mam")
      assert_equal(selection_texts(), {}, "mam should do nothing without a pair")
    end,
  },
  {
    name = "mim rust string ts",
    run = function()
      reset_case({ 'fn main() {func("string");}' }, "rust", 1, 20)
      run_keys("mim")
      assert_equal(selection_texts(), { "string" }, "rust mim should select string contents")
    end,
  },
  {
    name = "mm backticks bounce same pair",
    run = function()
      reset_case({ "- Figure out `direnv` + `lorri` and add support" }, "text", 1, 14)
      run_keys("mm")
      assert_equal(vim.api.nvim_win_get_cursor(0), { 1, 20 }, "first mm should jump to closing backtick")
      run_keys("mm")
      assert_equal(vim.api.nvim_win_get_cursor(0), { 1, 13 }, "second mm should jump back to opening backtick")
    end,
  },
  {
    name = "mim mam mim mam ts mix",
    run = function()
      reset_case({ 'fn main() {func("string");}' }, "rust", 1, 20)
      run_keys({ "mim", "mam", "mim", "mam" })
      assert_equal(selection_texts(), { '("string")' }, "mixed ts sequence should climb through structure")
    end,
  },
  {
    name = "mm rust string quotes",
    run = function()
      reset_case({ 'fn foo() -> &\'static str { "(hello world)" }' }, "rust", 1, 38)
      run_keys("mm")
      assert_equal(vim.api.nvim_win_get_cursor(0), { 1, 40 }, "mm should jump to closing quote in rust string")
      run_keys("mm")
      assert_equal(vim.api.nvim_win_get_cursor(0), { 1, 28 }, "second mm should jump back to opening quote")
    end,
  },
  {
    name = "plain fallback crosses lines",
    run = function()
      reset_case({ "before (", "text", ") after" }, "text", 2, 1)
      run_keys({ "mm", "mm" })
      assert_equal(vim.api.nvim_win_get_cursor(0), { 1, 7 }, "plaintext mm should match across lines")
    end,
  },
  {
    name = "ts sibling bracket match",
    run = function()
      reset_case({
        "fn foo(bar: Option<usize>) -> usize {",
        "    match bar {",
        "        Some(bar) => bar,",
        "        None => 42,",
        "    }",
        "}",
      }, "rust", 3, 13)
      run_keys({ "mm", "mm" })
      assert_equal(vim.api.nvim_win_get_cursor(0), { 3, 12 }, "ts sibling walk should find opening sibling bracket")
    end,
  },
  {
    name = "md failure leaves multicursor state intact",
    run = function()
      reset_case({ "plain text", "plain text" }, "text", 1, 3)
      helix.copy_selection_on_adjacent_line(1)
      run_keys("md(")
      assert_equal(current_lines(), { "plain text", "plain text" }, "md( should not edit when not found")
      assert_equal(secondary_cursor_count(), 1, "multicursor state should remain")
    end,
  },
}

table.insert(cases, {
  name = "mim multiple cursors shared outer pair",
  run = function()
    reset_case({ "(so (many (good) text) here", "so (many (good) text) here)" }, "text", 1, 24)
    helix.copy_selection_on_adjacent_line(1)
    run_keys("mim")
    assert_equal(selection_texts(), { "so (many (good) text) here\nso (many (good) text) here" }, "mim should support multiple cursors")
  end,
})

for _, case in ipairs(cases) do
  case.run()
end

print("match-tests-ok")
