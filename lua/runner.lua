local M = {}

---@class Runner
local Runner = {
  out = nil,
  err = nil,
  state_path = vim.fn.stdpath("data") .. "/" .. "runner",
}

---@class State
local State = {
  cmd = nil,
}

---@return string filepath
function Runner:current_file()
  -- local current_file = vim.uv.cwd() .. "/" .. vim.fn.expand('%')
  return vim.uv.cwd() .. "/test.py"
end

-- Returns the path to the state file for the current open file.
--- @return string
function Runner:state_file()
  local current_file = self:current_file()
  local current_file_state = self.state_path .. "/" .. vim.fn.sha256(current_file) .. ".json"
  return current_file_state
end

---@param state State
function Runner:write_state_file(state)
  local state_file = io.open(self:state_file(), "w")
  if state_file then
    state_file:write(vim.json.encode(state))
    state_file:close()
  else
    -- TODO
  end
end

--- @return State | nil
function Runner:try_read_state_file()
  local state_file = io.open(self:state_file(), "r")
  if state_file then
    local state = state_file:read("*a")
    local success, state_tbl = pcall(function()
      return vim.json.decode(state)
    end)
    if success then
      return state_tbl
    else
      return nil
    end
  end
end

function Runner:init()
  vim.fn.mkdir(self.state_path, "p")
  local state = self:try_read_state_file()
  if state then
    -- Run the command
    self.state = state
  else
    -- Prompt user for a command to run for the current_file.
    local cmd = vim.fn.input("cmd:", "", "shellcmdline")
    self.state = { cmd = cmd }
    self:write_state_file(state)
  end
  self:run()
end

--- @param cmd string
function Runner:run()
  local cmd = self.state.cmd
  if cmd then
    local job_id = vim.fn.jobstart(cmd, {
      stdout_buffered = true,
      on_stdout = function(_, data)
        self.out = data
      end,
      stderr_buffered = true,
      on_stderr = function(_, data)
        self.err = data
      end,
    })
    vim.fn.jobwait({ job_id })
    self:on_finish()
  else
    -- TODO maybe do something here
  end
end

function Runner:on_finish()
  local output_buffer = string.format("%s.out", self:current_file())
  vim.cmd('silent only') -- Close all windows apart from current
  vim.cmd('75vsplit')    -- Create new vertical split with 75 columns for new window

  -- Re-use old buffer with same name
  local bufnr = vim.fn.bufnr(output_buffer, false)
  if bufnr == -1 then
    bufnr = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_name(bufnr, output_buffer)

    -- Set buffer options
    vim.api.nvim_buf_set_option(0, 'modifiable', false)
    vim.api.nvim_buf_set_option(0, 'readonly', true)
  end
  vim.api.nvim_win_set_buf(0, bufnr)
  local errors = self.err
  local output = self.out
  local replacement = self.err
  if #replacement == 1 and replacement[1] == "" then 
    replacement = self.out
  end
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, replacement)
end

Runner:init()

return M
