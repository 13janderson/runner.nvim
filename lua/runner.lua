local M = {}

---@class Runner
local Runner = {
  out = nil,
  err = nil,
  state_path = vim.fn.stdpath("data") .. "/" .. "runner",
  registerd_handlers = {}
}

---@class State
local State = {
  cmd = nil,
  handler_module = nil,
}



-- Returns the path to the state file for the current open file.
--- @return string
function Runner:state_file()
  local current_file = vim.uv.cwd() .. "/" .. vim.fn.expand('%')
  local current_file_state = self.state_path .. "/" .. vim.fn.sha256(current_file) .. ".json"
  return current_file_state
end

---@param state State
function Runner:append_state_file(state)
  local current_state = self:try_read_file_state()
  local existing_state = current_state or {}
  Print(existing_state)

  local cmd = state.cmd
  local handler = state.handler_module
  local entry_for_cmd_exists = false

  for _, s in pairs(existing_state) do
    print("Overwriting existing handler for", cmd)
    if s.cmd == cmd then
      s.handler_module = handler
      entry_for_cmd_exists = true
    end
  end

  if not entry_for_cmd_exists then
    table.insert(existing_state, state)
  end
  
  local state_file = io.open(self:state_file(), "w")
  if state_file then
    state_file:write(vim.json.encode(existing_state))
    state_file:close()
  else
    -- TODO
  end

end

--- @return State[] | nil
function Runner:try_read_file_state()
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

-- Registers a handler for the current file and the specified cmd.
---@param cmd string specifies a command for run.
---@param handler_module string specifies the module name of the handler to be used when running this cmd.
function Runner:register_handler(cmd, handler_module)
  local loaded, handler = pcall(function () 
    return require(handler_module)
  end)
  if loaded then
    self:append_state_file({
      cmd = cmd,
      handler_module = handler_module
    })
    print("Handler registered")
  else
    print("Failed to register handler", handler, "please make sure this is on your nvim RTP")
  end
end

function Runner:init()
  vim.fn.mkdir(self.state_path, "p")
  -- local state_table = self:try_read_file_state()
  -- if not state_table then
    -- Need to prompt the user to for what handler to use
  -- end
end

--- @param cmd string
function Runner:run(cmd)
  local job_id = vim.fn.jobstart(cmd, {
    stderr_buffered = true,
    on_stderr = function(_, data)
      self.err = data
    end,
  })
  vim.fn.jobwait({ job_id })
  self:on_finish()
end

function Runner:on_finish()
  -- Clear qflist
  vim.fn.setqflist({}, 'f')
  -- Parse errors
  local errors = self.err
  if errors then
    local err = errors[#errors - 1]
    for _, v in pairs(errors) do
      local filepath = string.match(v, "File \"(.*)\"")
      local line = string.match(v, "line (%d)")
      if filepath and line then
        vim.fn.setqflist({
          { text = err, filename = filepath, lnum = line },
        }, "a")
      end
    end
  end

  vim.cmd('copen')
end

-- Runner:init()
-- Runner:register_handler("python test.py", "handler")
local cmd = "python test.py"
Runner:run(cmd)

return M
