-- Run with the Nix-built wrapper:
-- nix run .#neovim -- --headless -i NONE -l wrappers/neovim/tests/lean_goal_limit.lua
local goals = require("lean.goals")
local components = require("lean.infoview.components")
local Element = require("lean.tui").Element
local original_config = vim.g.lean_config
local original_buffer = vim.api.nvim_get_current_buf()
local buffer = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_name(buffer, vim.fn.tempname() .. ".txt")
vim.api.nvim_set_current_buf(buffer)
vim.bo.filetype = "text"

local function equal(actual, expected, label)
  assert(vim.deep_equal(actual, expected), label .. ": " .. vim.inspect(actual))
end

local function configure(limit)
  vim.g.lean_config = { infoview = { max_goals = limit } }
end

local calls = 0
local session = {
  pos = { textDocument = { uri = vim.uri_from_bufnr(buffer) }, position = { line = 0, character = 0 } },
  getInteractiveGoals = function(self)
    calls = calls + 1
    local response, err = self.response, self.err
    self.response, self.err = nil, nil
    return response, err
  end,
}

local function fixture(count, on_finalize)
  local result = { goals = {} }
  for i = 1, count do
    local goal = { mvarId = "goal-" .. i, hyps = {}, type = { text = "True" } }
    if on_finalize then
      -- Model lean.rpc's actual ownership pattern: the decoded RpcRef keeps
      -- its finalizer proxy alive through its metatable, not through a cache.
      local proxy = newproxy(true)
      getmetatable(proxy).__gc = on_finalize
      goal.ctx = setmetatable({ __rpcref = tostring(i) }, { [proxy] = true })
    end
    result.goals[i] = goal
  end
  return result
end

local function render()
  local blocks, err = components.goal_at(session, require("lean.config")().infoview.view_options)
  assert(not err, vim.inspect(err))
  return Element:new({ children = blocks or {} }):render_lines()
end

local ok, err = xpcall(function()
  configure(3)
  local finalized = 0
  session.response = fixture(5, function() finalized = finalized + 1 end)
  local weak = setmetatable({ original = session.response.goals, omitted = session.response.goals[4] }, { __mode = "v" })
  local limited, failure, total = goals.at(session)
  equal({ #limited, failure, total, calls }, { 3, nil, 5, 1 }, "oversized results retain their count")
  equal(limited[3].mvarId, "goal-3", "the original goal order is preserved")
  collectgarbage("collect")
  collectgarbage("collect")
  equal(weak.original, nil, "the cache must not retain the oversized array")
  equal(weak.omitted, nil, "the cache must not retain omitted goals")
  equal(finalized, 2, "omitted RPC references become collectible while displayed ones stay alive")

  local cached, _, cached_total = goals.at(session)
  equal({ cached == limited, cached_total, calls }, { true, 5, 1 }, "cache hits retain truncation metadata")
  local rendered = render()
  local text = table.concat(rendered.lines, "\n")
  assert(text:find("Showing 3 of 5 goals", 1, true), "truncation must be visible in the infoview")
  assert(vim.tbl_count(rendered.positions) < 100, "omitted goals must not become widgets")

  configure(5)
  session.response = fixture(5)
  local full, _, full_total = goals.at(session)
  equal({ #full, full_total, calls }, { 5, 5, 2 }, "changing the limit invalidates the old prefix cache")
  text = table.concat(render().lines, "\n")
  assert(not text:find("Showing", 1, true), "results at the limit should not show a truncation warning")

  -- The default must remain bounded even with the 41,096-entry response seen
  -- in the real reproduction. Keep IDs distinct to protect legitimate goals.
  configure(nil)
  session.response = fixture(41096)
  limited, _, total = goals.at(session)
  equal({ #limited, total }, { 100, 41096 }, "the default bounds pathological responses")
  rendered = render()
  assert(rendered.lines[1]:find("Showing 100 of 41096 goals", 1, true), "the original count survives caching and rendering")
  assert(vim.tbl_count(rendered.positions) < 2000, "widget allocations depend on the limit, not the full response")

  session.pos.position = { line = 0, character = 1 }
  session.response = { goals = {} }
  local empty, _, empty_total = goals.at(session)
  equal({ #empty, empty_total }, { 0, 0 }, "empty goal results remain valid")

  session.pos.position = { line = 0, character = 2 }
  session.err = { code = -32801, message = "content modified" }
  local missing, rpc_error = goals.at(session)
  equal(missing, nil, "RPC failures do not produce goals")
  equal(rpc_error.code, -32801, "RPC errors propagate unchanged")

  session.pos.position = { line = 0, character = 3 }
  equal(goals.at(session), nil, "absent goal results remain valid")

  for _, invalid in ipairs({ 0, -1, 1.5, math.huge, "unlimited" }) do
    configure(invalid)
    local valid, validation_error = pcall(goals.at, session)
    assert(not valid and tostring(validation_error):find("positive integer", 1, true), "invalid limits must fail clearly")
  end
end, debug.traceback)

vim.g.lean_config = original_config
vim.api.nvim_set_current_buf(original_buffer)
vim.api.nvim_buf_delete(buffer, { force = true })
assert(ok, err)
print("lean-goal-limit-tests-ok")
