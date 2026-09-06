local M = {
  maps = {},
  opts = {},
}

local state_path = vim.fn.stdpath("data") .. "/" .. "runner"
local options = {
  "makeprg",
  "errorformat",
}

local function check_opt(opt)
  for _, value in pairs(options) do
    if value == opt then
      return true
    end
  end
  return false
end

local git = require("git")
-- Returns the path to the state file for the current open file.
--- @return string
function M:state_file()
  local git_file_hash = git:git_file_hash()
  local current_file_state = state_path .. "/" .. git_file_hash .. ".json"
  return current_file_state
end

function M:write_state_file()
  local state_file = io.open(self:state_file(), "w")
  if state_file then
    state_file:write(vim.json.encode(self.opts))
    state_file:close()
  else
    error("failed to write to runner state file.")
  end
end

function M:try_read_opts()
  local state_file = io.open(self:state_file(), "r")
  if state_file then
    local state = state_file:read("*a")
    state_file:close()
    local success, opts = pcall(function()
      return vim.json.decode(state)
    end)

    if success then
      for key, value in pairs(opts) do
        vim.api.nvim_set_option_value(key, value, { scope = "local", buf = 0 })
      end
    else
      error("failed to read runner state file.")
    end
  end
  return state_file ~= nil
end

function M:setup_autocommands()
  -- listen to changes in option sets of interest
  vim.api.nvim_create_autocmd("OptionSet", {
    callback = function(ev)
      local match = ev.match
      if match ~= nil and check_opt(match) then
        local v = vim.api.nvim_get_option_value(match, { buf = ev.buf })
        self.opts[match] = v
        self:write_state_file()
      end
    end,
  })
  vim.api.nvim_create_autocmd({ "QuitPre", "VimLeavePre" }, {
    callback = function()
      require("runner").close()
    end,
  })
end

-- returns the uppercased version of a keymap by changing
-- the last key of the keymap to upper case
---@param keymap string
local function uppercase_lastkey(keymap)
  local len = keymap:len()
  return keymap:sub(0, len - 1) .. keymap:sub(len, len):upper()
end

---@class MakeOpts
---@field background boolean
---@field current boolean
---@param opts MakeOpts
function M:read_and_make(opts)
  local read_state = self:try_read_opts()
  opts = vim.tbl_deep_extend("force", { background = false, current = false }, opts)
  local arguments = ""

  -- Add trailing % for current file if not already present.
  if opts.current then
    local makeprg = vim.api.nvim_get_option_value("makeprg", { scope = "local" })
    if not makeprg:find("%%$") then
      arguments = "%"
    end
  end

  self:make(arguments, opts.background, read_state)
end

---@param arguments string
---@param background boolean
---@param read_state boolean|nil
function M:make(arguments, background, read_state)
  local makeprg = vim.api.nvim_get_option_value("makeprg", { scope = "local" })
  if makeprg == "" then
    error("runner: 'makeprg' is empty")
  end

  local command = makeprg
  if arguments ~= "" then
    command = command .. " " .. arguments
  end
  vim.notify("runner: " .. (read_state and "state " or "current ") .. command)
  local errorformat = vim.api.nvim_get_option_value("errorformat", { scope = "local" })
  require("runner").run(command, background, errorformat)
end

function M:setup_commands()
  vim.api.nvim_create_user_command("Make", function(command)
    self:make(command.args, command.bang)
  end, {
    bang = true,
    nargs = "*",
    force = true,
    desc = "Run 'makeprg' in runner's terminal",
  })
end

--- pick a command from shell history for the current file; the choice is
--- persisted as 'makeprg' via the state file and then run immediately
function M:pick_history()
  local buffer = vim.api.nvim_get_current_buf()
  require("history").pick(function(command)
    vim.api.nvim_set_option_value("makeprg", command, { buf = buffer, scope = "local" })
    self.opts.makeprg = command
    self.opts.errorformat = vim.api.nvim_get_option_value("errorformat", { buf = buffer })
    self:write_state_file()
    self:read_and_make({ background = false, current = false })
  end)
end

function M:setup_keymaps()
  local make = self.maps.make
  -- run make in foreground
  vim.keymap.set("n", make, function()
    self:read_and_make({ background = false, current = false })
  end)
  -- run make in background
  vim.keymap.set("n", uppercase_lastkey(make), function()
    self:read_and_make({ background = true, current = false })
  end)

  -- run make with current file wildcard, %, on the end
  local make_current = self.maps.make_current
  vim.keymap.set("n", make_current, function()
    self:read_and_make({ background = false, current = true })
  end)
  -- same as above but in the background
  vim.keymap.set("n", uppercase_lastkey(make_current), function()
    self:read_and_make({ background = true, current = true })
  end)

  -- pick a command from shell history, set it as 'makeprg' and run it
  local history = self.maps.history
  if history then
    vim.keymap.set("n", history, function()
      self:pick_history()
    end)
  end
end

---@class Keymaps
---@field make string
---@field make_current string
---@field history string

---@param maps Keymaps| nil
function M:setup(maps)
  maps = vim.tbl_deep_extend("force", {
    make = "<leader>mk",
    make_current = "<leader>mu",
    history = "<C-r>",
  }, maps or {})
  self.maps = maps
  vim.fn.mkdir(state_path, "p")
  self:setup_autocommands()
  self:setup_commands()
  self:setup_keymaps()
end

return M
