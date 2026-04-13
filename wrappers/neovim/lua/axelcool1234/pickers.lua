local M = {}

local function git_root_or_cwd()
  local root = vim.fn.system("git rev-parse --show-toplevel"):gsub("\n", "")
  if vim.v.shell_error == 0 and root ~= "" then
    return root
  end

  return vim.uv.cwd()
end

local function current_buffer_directory()
  local name = vim.api.nvim_buf_get_name(0)
  if name == "" then
    return vim.uv.cwd()
  end

  return vim.fn.fnamemodify(name, ":p:h")
end

local function find_files_in_directory(directory, opts)
  opts = vim.tbl_extend("force", { cwd = directory }, opts or {})
  require("telescope.builtin").find_files(opts)
end

local function scandir_entries(directory)
  local entries = {}
  local handle = vim.uv.fs_scandir(directory)
  if not handle then
    return entries
  end

  while true do
    local name, kind = vim.uv.fs_scandir_next(handle)
    if not name then
      break
    end

    entries[#entries + 1] = {
      name = name,
      kind = kind,
      path = directory .. "/" .. name,
    }
  end

  return entries
end

local function collapsed_directory_entry(directory, name)
  local parts = { name }
  local path = directory .. "/" .. name

  while true do
    local children = scandir_entries(path)
    if #children ~= 1 or children[1].kind ~= "directory" then
      break
    end

    parts[#parts + 1] = children[1].name
    path = children[1].path
  end

  return table.concat(parts, "/"), path
end

local function immediate_directory_entries(directory)
  local entries = {}
  local parent = vim.fs.dirname(directory)
  if parent and parent ~= directory then
    entries[#entries + 1] = {
      label = "../",
      name = "../",
      path = parent,
      is_dir = true,
      is_parent = true,
    }
  end

  for _, child in ipairs(scandir_entries(directory)) do
    local is_dir = child.kind == "directory"
    local label = child.name
    local path = child.path
    if is_dir then
      label, path = collapsed_directory_entry(directory, child.name)
    end

    entries[#entries + 1] = {
      label = label,
      name = label,
      path = path,
      is_dir = is_dir,
    }
  end

  table.sort(entries, function(left, right)
    if left.is_parent ~= right.is_parent then
      return left.is_parent == true
    end

    if left.is_dir ~= right.is_dir then
      return left.is_dir == true
    end

    return left.path < right.path
  end)

  return entries
end

local function entry_display_label(entry)
  if not entry.is_dir then
    return entry.label
  end

  return entry.label:sub(-1) == "/" and entry.label or (entry.label .. "/")
end

local function directory_preview_lines(directory)
  local entries = immediate_directory_entries(directory)
  if #entries == 0 then
    return { "<empty directory>" }
  end

  local lines = {}
  for _, entry in ipairs(entries) do
    lines[#lines + 1] = entry_display_label(entry)
  end

  return lines
end

local function open_directory_picker(directory, title)
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local config = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local previewers = require("telescope.previewers")

  pickers.new({}, {
    prompt_title = title,
    sorting_strategy = "ascending",
    layout_config = {
      prompt_position = "top",
    },
    finder = finders.new_table({
      results = immediate_directory_entries(directory),
      entry_maker = function(entry)
        return {
          value = entry,
          display = entry_display_label(entry),
          ordinal = (entry.is_dir and "0" or "1") .. entry.name,
        }
      end,
    }),
    sorter = config.generic_sorter({}),
    previewer = previewers.new_buffer_previewer({
      define_preview = function(self, entry)
        local item = entry.value
        if item.is_dir then
          vim.bo[self.state.bufnr].filetype = ""
          vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, directory_preview_lines(item.path))
          return
        end

        config.buffer_previewer_maker(item.path, self.state.bufnr, {
          bufname = self.state.bufname,
          winid = self.state.winid,
        })
      end,
    }),
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        if not selection then
          return
        end

        local entry = selection.value
        if entry.is_dir then
          vim.schedule(function()
            open_directory_picker(entry.path, title)
          end)
          return
        end

        vim.cmd.edit(vim.fn.fnameescape(entry.path))
      end)

      return true
    end,
  }):find()
end

function M.find_files_in_git_root()
  find_files_in_directory(git_root_or_cwd())
end

function M.live_grep_in_git_root()
  local root = vim.fn.system("git rev-parse --show-toplevel"):gsub("\n", "")
  if vim.v.shell_error == 0 then
    require("telescope.builtin").live_grep({ cwd = root })
  else
    require("telescope.builtin").live_grep()
  end
end

function M.find_files_in_cwd()
  find_files_in_directory(vim.uv.cwd())
end

function M.find_files_in_directory(directory, opts)
  find_files_in_directory(directory, opts)
end

function M.open_workspace_explorer()
  open_directory_picker(git_root_or_cwd(), "Workspace Explorer")
end

function M.open_buffer_directory_explorer()
  open_directory_picker(current_buffer_directory(), "Buffer Directory Explorer")
end

function M.buffer_picker()
  require("telescope.builtin").buffers({
    sort_mru = true,
  })
end

function M.jumplist_picker()
  require("telescope.builtin").jumplist()
end

function M.document_symbols_picker()
  require("telescope.builtin").lsp_document_symbols()
end

function M.workspace_symbols_picker()
  require("telescope.builtin").lsp_dynamic_workspace_symbols()
end

function M.diagnostics_picker()
  require("telescope.builtin").diagnostics({
    bufnr = 0,
    sort_by = "severity",
  })
end

function M.workspace_diagnostics_picker()
  require("telescope.builtin").diagnostics({
    sort_by = "severity",
  })
end

function M.references_picker()
  require("telescope.builtin").lsp_references()
end

function M.resume_last_picker()
  require("telescope.builtin").resume()
end

return M
