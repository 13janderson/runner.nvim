local M = {}

---@class Runner
local Runner = {
  out = nil,
  err = nil,
  state_path = vim.fn.stdpath("data") .. "/" .. "runner",
}

---@class State
local State = {
  file = nil,
  cmd = nil
}

-- Constructs a State object and sets its meta table to be the State table
-- so that all State objects can use these shared methods.
---@param state State
function State:new(state)
  self.__index = self
  setmetatable(state, self)
  return state
end

-- Changes the focus to the provided window by winnr, if that window is valid.
---@param winnr integer the window number to change focus to.
function State:change_window_focus(winnr)
  if vim.api.nvim_win_is_valid(winnr) then
    vim.api.nvim_set_current_win(winnr)
  end
end

function State:focus_output_win()
  self:change_window_focus(self.out_winnr)
end

function State:focus_source_win()
  self:change_window_focus(self.src_winnr)
end

---@param tbl table
function State:show_out(tbl)
  self.output_buffer = string.format("%s.out", self.file)

  -- Re-use old buffer with same name
  local bufnr = vim.fn.bufnr(self.output_buffer, false)
  if bufnr == -1 then
    bufnr = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_name(bufnr, self.output_buffer)

    -- Set buffer options
    vim.api.nvim_set_option_value('modifiable', false, {
      buf = bufnr,
    })
    vim.api.nvim_set_option_value('buftype', 'nofile', {
      buf = bufnr,
    })
  end

  self.src_winnr = vim.api.nvim_get_current_win()
  self.out_winnr = vim.api.nvim_open_win(bufnr, true, {
    split = 'right',
    width = 60,
    win = 0
  })

  self.out_bufnr = bufnr

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, tbl)

  vim.api.nvim_create_autocmd('BufWinEnter', {
    desc = 'Re-direct new buffers to another win.',
    group = vim.api.nvim_create_augroup('Buffer-Win-Redirect', { clear = true }),
    callback = function(_)
      vim.schedule(function()
        -- Check that the windows current buffer is the self.out_bufnr
        if vim.api.nvim_win_is_valid(self.out_winnr) then
          local openbufnr = vim.api.nvim_win_get_buf(self.out_winnr)
          if openbufnr ~= self.out_bufnr then
            -- print("New bufnr opened", openbufnr)

            -- print("Opening",  self.out_bufnr, "in", self.out_winnr)
            vim.api.nvim_win_set_buf(self.out_winnr, self.out_bufnr)

            -- print("Opening", openbufnr, "in", self.src_winnr)
            vim.api.nvim_win_set_buf(self.src_winnr, openbufnr)
            -- Additionally focus window with this in.

            self:focus_source_win()
          end
        end
      end)
    end,
  })
end

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

function Runner:write_state_file()
  local state_file = io.open(self:state_file(), "w")
  if state_file then
    state_file:write(vim.json.encode(self.state))
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
      return State:new(state_tbl)
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
    self.state = State:new(self.state)
  else
    -- Prompt user for a command to run for the current_file.
    local cmd = vim.fn.input("cmd:", "", "shellcmdline")
    self.state = State:new({
      file = self:current_file(),
      cmd = cmd
    })
    self:write_state_file()
  end
  self:run()
end

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

    local show = self.err
    if #show == 1 and show[1] == "" then
      show = self.out
    end

    self.state:show_out(show)
  else
    -- TODO maybe do something here
  end
end

Runner:init()

return M
