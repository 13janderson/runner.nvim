local M = {}

---@param cmd table
---@return string|nil
local run = function(cmd)
  local ret = vim.system(cmd):wait(2000)

  local stdout = ret.stdout
  if stdout then
    return vim.trim(stdout)
  end

  local stderr = ret.stderr
  if stderr then
    print("Error running Git command", stderr)
  end
  return nil
end

---@return string | nil
function M:repo()
  return run({ "git", "rev-parse", "--show-toplevel" })
end

---@return string | nil
function M:branch()
  return run({ "git", "rev-parse", "--abbrev-ref", "HEAD" })
end

local Path = require("plenary.path")
function M:file()
  local full_buffer_path = Path:new(vim.fn.expand("%:p"))
  local repo = M:repo()
  if repo ~= nil then
    return full_buffer_path:make_relative(repo)
  end
  return full_buffer_path
end

---@return string | nil
function M:git_file_hash()
  local repo = self:repo() or ""
  local branch = self:branch() or ""
  local file = self:file()

  return vim.fn.sha256(repo .. branch .. file)
end

return M
