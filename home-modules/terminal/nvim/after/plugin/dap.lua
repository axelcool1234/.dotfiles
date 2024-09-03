local dap = require('dap')
local dapui = require('dapui')

local function get_lldb_path()
  return vim.fn.system('which lldb'):gsub('%s+$', '') -- Remove trailing whitespace
end

dapui.setup()

dap.adapters.lldb = {
  type = 'executable',
  command = get_lldb_path(),
  name = 'lldb'
}

dap.listeners.before.attach.dapui_config = function()
  dapui.open()
end
dap.listeners.before.launch.dapui_config = function()
  dapui.open()
end
dap.listeners.before.event_terminated.dapui_config = function()
  dapui.close()
end
dap.listeners.before.event_exited.dapui_config = function()
  dapui.close()
end
