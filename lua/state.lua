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

---@class State
local M = {
  -- file = nil,
  -- makeprg = nil,
  -- compiler = nil,
  opts = {},
}

---@return string filepath
function M:current_file()
  return vim.uv.cwd() .. "/" .. vim.fn.expand("%")
end

-- Returns the path to the state file for the current open file.
--- @return string
function M:state_file()
  local current_file = self:current_file()
  local current_file_state = state_path .. "/" .. vim.fn.sha256(current_file) .. ".json"
  return current_file_state
end

function M:write_state_file()
  local state_file = io.open(self:state_file(), "w")
  if state_file then
    state_file:write(vim.json.encode(self.opts))
    state_file:close()
  else
    -- TODO
  end
end

function M:try_read_opts()
  local state_file = io.open(self:state_file(), "r")
  if state_file then
    local state = state_file:read("*a")
    local success, opts = pcall(function()
      return vim.json.decode(state)
    end)

    if success then
      for key, value in pairs(opts) do
        vim.api.nvim_set_option_value(key, value, { scope = "local", buf = 0 })
      end
    else
      -- TO DO
    end
  end
end

function M:setup_autocommands()
  -- listen to changes in option sets of intest
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
end

local foo = "foo %"
local bar = foo[string.len(foo)]

print("bar", bar)
if foo[string.len(foo)] == "%" then
  print("perc", foo)
end

-- returns the uppercased version of a keymap by changing
-- the last key of the keymap to upper case
---@param keymap string
local function uppercase_lastkey(keymap)
  local len = keymap:len()
  return keymap:sub(0, len - 1) .. keymap:sub(len, len):upper()
end

---@param opts table
function M:setup_keymaps(opts)
  vim.keymap.set("n", opts.make, function()
    self:try_read_opts()
    vim.cmd('Make')
  end)
  vim.keymap.set("n", uppercase_lastkey(opts.make), function()
    self:try_read_opts()
    vim.cmd('Make!')
  end)
end

---@class Keymaps
---@field make string
local Keymaps = {}

---@class SetupOpts
---@field keymaps Keymaps
local SetupOpts = {}

---@param opts SetupOpts | nil
function M:setup(opts)
  opts = opts or {
    keymaps = {
      make = "<leader>mk",
    },
  }

  vim.fn.mkdir(state_path, "p")
  self:setup_autocommands()
  self:setup_keymaps(opts.keymaps)
end

M:setup()

return M
