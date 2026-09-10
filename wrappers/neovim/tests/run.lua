local test_dir = vim.fs.dirname(debug.getinfo(1, "S").source:sub(2))
local files = vim.fn.globpath(test_dir, "*.lua", false, true)
local runner = vim.fs.joinpath(test_dir, "run.lua")

table.sort(files)
vim.o.swapfile = false

local executed = 0
for _, file in ipairs(files) do
  if vim.fs.normalize(file) ~= vim.fs.normalize(runner) then
    local name = vim.fs.basename(file)
    io.stdout:write(("running %s\n"):format(name))
    local ok, err = xpcall(function()
      dofile(file)
    end, debug.traceback)
    if not ok then
      error(("%s failed:\n%s"):format(name, err))
    end
    executed = executed + 1
  end
end

assert(executed > 0, "no Neovim Lua tests were discovered")
print(("all-neovim-tests-ok (%d files)"):format(executed))
