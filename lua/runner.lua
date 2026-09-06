local M = {
  buffer = nil,
  job = nil,
  restore_terminal_session = nil,
  reuse_window = nil,
}

local function valid_buffer()
  return M.buffer and vim.api.nvim_buf_is_valid(M.buffer)
end

local function close_previous_buffer()
  M.reuse_window = nil
  if valid_buffer() then
    for _, window in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_buf(window) == M.buffer then
        M.reuse_window = window
      end
    end
    vim.api.nvim_buf_delete(M.buffer, { force = true })
  end
  M.buffer = nil
end

local function exclude_terminal_from_session()
  M.restore_terminal_session = vim.tbl_contains(vim.opt.sessionoptions:get(), "terminal")
  vim.opt.sessionoptions:remove("terminal")
end

local function restore_terminal_session()
  if M.restore_terminal_session then
    vim.opt.sessionoptions:append("terminal")
  end
  M.restore_terminal_session = nil
end

local function create_buffer()
  close_previous_buffer()
  exclude_terminal_from_session()
  M.buffer = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(M.buffer, "runner://output")
  vim.bo[M.buffer].bufhidden = "wipe"
  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = M.buffer,
    once = true,
    callback = function()
      M.buffer = nil
      restore_terminal_session()
    end,
  })
  return M.buffer
end

-- displays the runner buffer without stealing focus, returning its window
local function open_buffer()
  if not valid_buffer() then
    return nil
  end

  for _, window in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(window) == M.buffer then
      return window
    end
  end

  local focus_window
  local window = M.reuse_window
  if window == nil or not vim.api.nvim_win_is_valid(window) then
    focus_window = vim.api.nvim_get_current_win()
    vim.cmd("botright split")
    window = vim.api.nvim_get_current_win()
  end
  M.reuse_window = nil

  vim.api.nvim_win_set_buf(window, M.buffer)
  vim.api.nvim_win_set_height(window, math.floor(vim.o.lines * 0.25))
  vim.wo[window].winfixheight = true
  if focus_window then
    vim.api.nvim_set_current_win(focus_window)
  end
  return window
end

local function expand_command(command)
  return vim.fn.expandcmd(command)
end

local function populate_quickfix(buffer, command, errorformat)
  local lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
  while lines[#lines] == "" do
    table.remove(lines)
  end

  local quickfix = { title = "runner: " .. command }
  if errorformat == "" then
    quickfix.items = {}
  else
    quickfix.lines = lines
    quickfix.efm = errorformat
  end
  vim.fn.setqflist({}, " ", quickfix)
end

local function open_results()
  local focus_window = vim.api.nvim_get_current_win()
  local terminal_window = open_buffer()
  if terminal_window == nil then
    return
  end

  vim.cmd("silent! cclose")
  vim.cmd("copen")
  local quickfix_window = vim.api.nvim_get_current_win()
  local quickfix_buffer = vim.api.nvim_win_get_buf(quickfix_window)
  vim.api.nvim_set_current_win(terminal_window)
  vim.cmd("rightbelow vsplit")
  vim.api.nvim_win_set_buf(0, quickfix_buffer)
  vim.api.nvim_win_close(quickfix_window, true)
  vim.api.nvim_win_set_height(terminal_window, math.floor(vim.o.lines * 0.25))

  if vim.api.nvim_win_is_valid(focus_window) then
    vim.api.nvim_set_current_win(focus_window)
  end
end

--- Run a command in the dedicated terminal buffer.
--- @param command string
--- @param background boolean
--- @param errorformat string
function M.run(command, background, errorformat)
  if M.job then
    vim.notify("runner: a command is already running", vim.log.levels.WARN)
    return
  end

  command = expand_command(command)
  local buffer = create_buffer()
  if not background then
    open_buffer()
  end

  vim.api.nvim_buf_call(buffer, function()
    M.job = vim.fn.termopen(command, {
      on_exit = function()
        M.job = nil
        vim.schedule(function()
          if not valid_buffer() or M.buffer ~= buffer then
            return
          end
          populate_quickfix(buffer, command, errorformat)
          open_results()
        end)
      end,
    })
  end)
end

function M.close()
  vim.cmd("silent! cclose")
  if M.job then
    vim.fn.jobstop(M.job)
  end
  -- displayed buffers wipe themselves via 'bufhidden' when their window closes
  if valid_buffer() and #vim.fn.win_findbuf(M.buffer) == 0 then
    vim.api.nvim_buf_delete(M.buffer, { force = true })
  end
  -- prevent the scheduled on_exit callback from opening results during shutdown
  M.job = nil
  M.buffer = nil
end

return M
