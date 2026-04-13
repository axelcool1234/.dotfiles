local M = {}

function M.new(opts)
  local state = opts.state
  local snapshot_limit = opts.snapshot_limit or 200
  local histories = {}

  local history = {}

  local function current_undo_seq()
    local seq = vim.fn.undotree().seq_cur
    return type(seq) == "number" and seq or 0
  end

  local function history_for_buffer(buffer)
    local existing = histories[buffer]
    if existing then
      return existing
    end

    local created = {
      seqs = {},
      snapshots = {},
    }
    histories[buffer] = created
    return created
  end

  local function seq_index(buffer_history, seq)
    for index, existing in ipairs(buffer_history.seqs) do
      if existing == seq then
        return index
      end
    end

    return nil
  end

  local function truncate_after_index(buffer_history, index)
    for remove_index = #buffer_history.seqs, index + 1, -1 do
      local seq = table.remove(buffer_history.seqs, remove_index)
      buffer_history.snapshots[seq] = nil
    end
  end

  local function prune_history(buffer)
    local buffer_history = history_for_buffer(buffer)
    while #buffer_history.seqs > snapshot_limit do
      local seq = table.remove(buffer_history.seqs, 1)
      buffer_history.snapshots[seq] = nil
    end
  end

  local function record_snapshot(buffer, seq, entries, config, branch_from_seq)
    if #entries == 0 then
      return false
    end

    local buffer_history = history_for_buffer(buffer)
    local branch_index = branch_from_seq and seq_index(buffer_history, branch_from_seq) or nil
    if branch_index and seq ~= branch_from_seq and branch_index < #buffer_history.seqs then
      truncate_after_index(buffer_history, branch_index)
    end

    local existing_index = seq_index(buffer_history, seq)

    local snapshot = {
      entries = vim.deepcopy(entries),
      cursor_positions = vim.deepcopy(config.cursor_positions or {}),
      preferred_columns = vim.deepcopy(config.preferred_columns or {}),
    }

    buffer_history.snapshots[seq] = snapshot
    if not existing_index then
      table.insert(buffer_history.seqs, seq)
    end
    prune_history(buffer)
    return true
  end

  local function current_snapshot_entries()
    local entries = state.current_entries()
    local config = {}

    if state.preview_active() then
      config.cursor_positions = vim.deepcopy(state.preview.cursor_positions or {})
      config.preferred_columns = vim.deepcopy(state.preview.preferred_columns or {})
    end

    return entries, config
  end

  local function materialize_snapshot(snapshot)
    return vim.deepcopy(snapshot.entries or {}), {
      cursor_positions = vim.deepcopy(snapshot.cursor_positions or {}),
      preferred_columns = vim.deepcopy(snapshot.preferred_columns or {}),
    }
  end

  local function snapshot_for_seq(buffer, seq)
    return history_for_buffer(buffer).snapshots[seq]
  end

  local function current_snapshot_index(buffer)
    return seq_index(history_for_buffer(buffer), current_undo_seq())
  end

  function history.begin_change(entries, config)
    local buffer = vim.api.nvim_get_current_buf()
    local seq = current_undo_seq()
    return {
      before_seq = seq,
      buffer = buffer,
      stored = record_snapshot(buffer, seq, vim.deepcopy(entries), config or {}),
    }
  end

  function history.finish_change(change)
    if not change or not change.stored then
      return false
    end

    if not vim.api.nvim_buf_is_valid(change.buffer) or vim.api.nvim_get_current_buf() ~= change.buffer then
      return false
    end

    local after_seq = current_undo_seq()
    if after_seq == change.before_seq then
      return false
    end

    local entries, config = current_snapshot_entries()
    return record_snapshot(change.buffer, after_seq, entries, config, change.before_seq)
  end

  function history.capture_current_seq()
    local buffer = vim.api.nvim_get_current_buf()
    if not vim.api.nvim_buf_is_valid(buffer) then
      return false
    end

    local entries, config = current_snapshot_entries()
    return record_snapshot(buffer, current_undo_seq(), entries, config)
  end

  function history.attach()
    state.set_history_sync(function()
      history.capture_current_seq()
    end)
  end

  function history.transaction(entries, config)
    local change = history.begin_change(entries, config)
    local finished = false

    local function finish()
      if finished then
        return false
      end

      finished = true
      return history.finish_change(change)
    end

    return {
      commit_now = finish,
      lifecycle = function(join_previous_change)
        return {
          on_finish = finish,
          join_previous_change = join_previous_change == true,
        }
      end,
    }
  end

  function history.restore_after_jump(after_seq)
    local buffer = vim.api.nvim_get_current_buf()
    local snapshot = snapshot_for_seq(buffer, after_seq)
    if not snapshot then
      return false
    end

    local entries, config = materialize_snapshot(snapshot)
    if #entries == 0 then
      return false
    end

    state.exit_extend_mode()
    config.sync_history = false
    state.set_preview_entries(buffer, entries, config)
    return true
  end

  local function jump_to_snapshot(offset)
    local buffer = vim.api.nvim_get_current_buf()
    local buffer_history = history_for_buffer(buffer)
    if #buffer_history.seqs == 0 then
      return false
    end

    local current_seq = current_undo_seq()
    local current_index = seq_index(buffer_history, current_seq)
    if not current_index then
      return false
    end

    local target_index = current_index + offset
    if target_index < 1 or target_index > #buffer_history.seqs then
      return false
    end

    local target_seq = buffer_history.seqs[target_index]
    if current_seq ~= target_seq then
      local ok = pcall(vim.cmd, ("undo %d"):format(target_seq))
      if not ok then
        return false
      end
    end

    return history.restore_after_jump(target_seq)
  end

  function history.can_navigate_current_seq(offset)
    local buffer = vim.api.nvim_get_current_buf()
    local buffer_history = history_for_buffer(buffer)
    local current_index = current_snapshot_index(buffer)
    if not current_index then
      return false
    end

    local target_index = current_index + offset
    return target_index >= 1 and target_index <= #buffer_history.seqs
  end

  function history.undo_snapshot()
    return jump_to_snapshot(-1)
  end

  function history.redo_snapshot()
    return jump_to_snapshot(1)
  end

  function history.clear_buffer(buffer)
    histories[buffer] = nil
  end

  return history
end

return M
