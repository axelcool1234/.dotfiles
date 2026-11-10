-- Run with the Nix-built wrapper:
-- nix run .#neovim -- --headless -i NONE -l wrappers/neovim/tests/lean_rpc_cancellation.lua
local requests = require 'lean.rpc.request'
local rpc = require 'lean.rpc'
local async = require 'std.async'
local Buffer = require 'std.nvim.buffer'

local function equal(actual, expected, label)
  assert(vim.deep_equal(actual, expected), label .. ': ' .. vim.inspect(actual))
end
local function wait_for(fn, label)
  assert(vim.wait(1000, fn, 1), label)
end
local function upvalue(fn, name)
  for i = 1, 50 do
    local key, value = debug.getupvalue(fn, i)
    if key == name then return value end
    if key == nil then break end
  end
  error('missing upvalue ' .. name)
end
local function client()
  return {
    sent = {}, cancelled = {}, notifications = {},
    request = function(self, method, params, callback)
      local id = #self.sent + 1
      self.sent[id] = { method = method, params = params, reply = callback }
      return true, id
    end,
    cancel_request = function(self, id)
      -- Deliberately no callback: Neovim swallows RequestCancelled ACKs.
      self.cancelled[#self.cancelled + 1] = id
      return true
    end,
    notify = function(self, method, params)
      self.notifications[#self.notifications + 1] = { method = method, params = params }
      return true
    end,
    is_stopped = function() return false end,
  }
end
local function start(context, fn)
  local task = { done = false }
  local co = coroutine.create(function()
    task.result, task.err = requests.run(context, fn)
    task.done = true
  end)
  local ok, err = coroutine.resume(co)
  assert(ok, err)
  task.co = co
  return task
end
local function query(context, c, discard)
  return start(context, function()
    local err, result = requests.request(c, 'test', {}, discard)
    return result, err
  end)
end
local function cancelled(task, label)
  wait_for(function() return task.done end, label .. ' must finish without an ACK')
  equal(task.err.code, -32800, label .. ' reports cancellation')
  equal(task.result, nil, label .. ' cannot return stale data')
  equal(coroutine.status(task.co), 'dead', label .. ' leaves no suspended coroutine')
end

-- A cancelled scope completes exactly once; another scope is independent.
local c, a, b = client(), requests.new_context(), requests.new_context()
local released = 0
local old = query(a, c, function() released = released + 1 end)
local current = query(b, c)
a:cancel()
a:cancel()
cancelled(old, 'obsolete request')
equal(c.cancelled, { 1 }, 'cancellation belongs to one scope')
assert(not current.done, 'another pin must remain in flight')
c.sent[1].reply(nil, { stale = true })
c.sent[1].reply(nil, { stale = true })
equal(released, 1, 'late replies are discarded exactly once')
c.sent[2].reply(nil, { current = true })
wait_for(function() return current.done end, 'current request completes')
equal(current.result, { current = true }, 'another pin receives its own data')
equal(next(a.pending), nil, 'cancelled callbacks are removed')
equal(next(b.pending), nil, 'completed callbacks are removed')

-- A response may already be queued when the cursor moves.
c, a = client(), requests.new_context()
released = 0
old = query(a, c, function() released = released + 1 end)
c.sent[1].reply(nil, { stale = true })
a:cancel()
cancelled(old, 'queued response')
equal(released, 1, 'queued data is released instead of delivered')

-- In-process LSP servers may reply or cancel synchronously inside request().
c, a = client(), requests.new_context()
c.request = function(_, _, _, cb) cb(nil, 'synchronous'); return true, 1 end
current = query(a, c)
wait_for(function() return current.done end, 'synchronous callback completes')
equal(current.result, 'synchronous', 'callbacks wait for the coroutine to yield')
c.request = function() a:cancel(); return true, 2 end
a:cancel()
old = query(a, c) -- Already cancelled: must not send another request.
cancelled(old, 'already cancelled scope')
equal(c.cancelled, {}, 'unsent requests require no protocol cancellation')
a = requests.new_context()
c.request = function() a:cancel(); return true, 3 end
old = query(a, c)
cancelled(old, 'synchronous cancellation')
equal(c.cancelled, { 3 }, 'cancellation during send still cancels its request ID')
c, a = client(), requests.new_context()
c.request = function() return false end
old = query(a, c)
wait_for(function() return old.done end, 'failed send completes')
equal(old.err.code, -32603, 'failed sends do not strand waiters')

-- Nested ownership is restored even when a callback throws.
a, b = requests.new_context(), requests.new_context()
local restored = start(a, function()
  local ok = pcall(requests.run, b, function() error('expected test error') end)
  assert(not ok)
  b:cancel()
  assert(not requests.is_cancelled(), 'the outer context must be restored')
  a:cancel()
  assert(requests.is_cancelled(), 'the restored context remains cancellable')
end)
assert(restored.done)

local buffer = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_name(buffer, vim.fn.tempname() .. '.txt')
vim.api.nvim_buf_set_lines(buffer, 0, -1, false, { 'test' })
local params = { textDocument = { uri = vim.uri_from_bufnr(buffer) }, position = { line = 0, character = 0 } }
local Session = upvalue(upvalue(rpc.open, 'connect'), 'Session')
local Subsession = upvalue(rpc.open, 'ReconnectingSubsession')

-- Exercise real Session:call, including reference release in both wire formats.
for _, key in ipairs({ 'p', '__rpcref' }) do
  c, a = client(), requests.new_context()
  c.server_capabilities = { experimental = { rpcProvider = { rpcWireFormat = key == 'p' and 'v0' or 'v1' } } }
  local session = Session:new(c, Buffer:from_bufnr(buffer), params.textDocument.uri)
  session.connected, session.session_id = true, 42
  local sub = Subsession:new(session, params)
  old = start(a, function() return sub:getInteractiveGoals() end)
  a:cancel()
  cancelled(old, 'RPC session ' .. key)
  local refs = { { [key] = '1' }, { nested = { [key] = '2' } } }
  c.sent[1].reply(nil, { goals = refs })
  wait_for(function() return #c.notifications > 0 end, 'late server references are released')
  equal(c.notifications[1], {
    method = '$/lean/rpc/release',
    params = { uri = params.textDocument.uri, sessionId = 42, refs = { { [key] = '1' }, { [key] = '2' } } },
  }, 'release retains the negotiated wire format')
  equal(getmetatable(refs[1]), nil, 'discarded replies never acquire finalizer proxies')
  -- This subsession may be captured in links in an earlier rendered widget.
  local unscoped_done = false
  async.run(function()
    local result, err = sub:getInteractiveGoals()
    assert(not err and result.usable)
    unscoped_done = true
  end)
  c.sent[2].reply(nil, { usable = true })
  wait_for(function() return unscoped_done end, 'cached subsessions remain usable outside their old scope')
  session:close()
end

-- A shared connect handshake belongs to the session, not either caller.
local lsp = require 'lean.lsp'
local original_client_for = lsp.client_for
c, a, b = client(), requests.new_context(), requests.new_context()
lsp.client_for = function() return c end
local first, second
old = start(a, function() first = rpc.open(params); return first:getInteractiveGoals() end)
current = start(b, function() second = rpc.open(params); return second:getInteractiveGoals() end)
equal(#c.sent, 1, 'pins share a single connection handshake')
a:cancel()
equal(c.cancelled, {}, 'one pin must never cancel a shared handshake')
cancelled(old, 'cancelled handshake waiter before connect finishes')
c.sent[1].reply(nil, { sessionId = 43 })
wait_for(function() return #c.sent == 2 end, 'the remaining pin proceeds after connect')
cancelled(old, 'cancelled handshake waiter')
equal(c.sent[2].params.method, 'Lean.Widget.getInteractiveGoals', 'only the live pin sends a goal request')
c.sent[2].reply(nil, { goals = {} })
wait_for(function() return current.done end, 'live pin completes after shared connect')
first.sess:close()
lsp.client_for = original_client_for

-- Drive real Pin:update / pause / teardown with controlled asynchronous replies.
local infoview = require 'lean.infoview'
local Infoview = upvalue(infoview.open, 'Infoview')
local Pin = upvalue(Infoview.new, 'Pin')
c = client()
local rendered, refreshes = {}, 0
local iv = {
  window = { is_current = function() return true end },
  view_options = {},
  __update_winhighlight = function() end,
  __refresh_diff = function() end,
  render_contents = function()
    local err, result = requests.request(c, 'render', {})
    return err and 'cancelled' or result
  end,
}
local pin = setmetatable({
  __infoview = iv, __position_params = vim.deepcopy(params), __tick = 0,
  __data_element = 'initial',
  __element = { set_children = function(_, children) rendered[#rendered + 1] = children[1] end },
  __renderer = { detach_window = function() end, close = function() end },
  render = function() end,
  request_update = function() refreshes = refreshes + 1 end,
}, Pin)
pin:update()
pin:update()
pin:update()
equal(#c.sent, 1, 'identical in-flight updates are coalesced')
c.sent[1].reply(nil, 'first')
wait_for(function() return not pin.loading end, 'first pin update completes')
equal(refreshes, 1, 'progress notifications retain just one follow-up refresh')
equal(rendered, { 'first' }, 'the active update renders normally')

pin:update()
pin.__position_params = vim.deepcopy(params)
pin.__position_params.position.character = 1
pin:update()
equal(c.cancelled, { 2 }, 'moving the pin cancels its old request')
c.sent[3].reply(nil, 'latest')
wait_for(function() return pin.__data_element == 'latest' end, 'latest position renders')
c.sent[2].reply(nil, 'stale')
vim.wait(10)
equal(pin.__data_element, 'latest', 'a stale reply cannot overwrite stored or rendered data')
equal(rendered, { 'first', 'latest' }, 'stale widgets never reach the renderer')

pin:update()
vim.api.nvim_buf_set_lines(buffer, 0, -1, false, { 'edited' })
pin:update()
equal(c.cancelled, { 2, 4 }, 'document changes invalidate the old request at the same position')
iv.view_options = { show_types = false }
pin:update()
equal(c.cancelled, { 2, 4, 5 }, 'view option changes invalidate the old request')
pin:pause()
equal(c.cancelled, { 2, 4, 5, 6 }, 'pausing cancels pending work')
assert(not pin.loading)
pin:unpause()
pin:__window_was_closed()
equal(c.cancelled, { 2, 4, 5, 6, 7 }, 'closing the pin cancels pending work')
pin:update()
pin:__teardown()
equal(c.cancelled, { 2, 4, 5, 6, 7, 8 }, 'teardown cancels pending work')
vim.wait(10)
equal(pin.__data_element, 'latest', 'cancelled updates cannot replace the last valid data')

-- Closing the whole view also cancels its pinned and diff work; another
-- tabpage's pin must remain independent.
local main, extra, diff, other = requests.new_context(), requests.new_context(), requests.new_context(), requests.new_context()
local function pending_pin(context)
  return setmetatable({ __request_context = context, __renderer = { detach_window = function() end } }, Pin)
end
Infoview.__was_closed {
  window = {}, pin = pending_pin(main), pins = { pending_pin(extra) }, __diff_pin = pending_pin(diff),
}
assert(main.cancelled and extra.cancelled and diff.cancelled, 'all pins in a closed infoview are cancelled')
assert(not other.cancelled, 'other infoviews remain active')

vim.api.nvim_buf_delete(buffer, { force = true })
print('lean-rpc-cancellation-tests-ok')
