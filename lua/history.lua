local M = {}

local function candidates()
  local home = vim.fn.expand("~")
  local data = vim.env.XDG_DATA_HOME or (home .. "/.local/share")
  local files = {}
  if vim.env.HISTFILE and vim.env.HISTFILE ~= "" then
    table.insert(files, vim.env.HISTFILE)
  end
  table.insert(files, data .. "/fish/fish_history")
  table.insert(files, home .. "/.zsh_history")
  table.insert(files, home .. "/.bash_history")
  return files
end

local function parse_fish(lines)
  local entries = {}
  local current = nil
  for _, line in ipairs(lines) do
    local cmd = line:match("^%- cmd: (.*)")
    if cmd then
      if current then
        table.insert(entries, current)
      end
      current = cmd
    elseif current and line:match("^%s+when:") then
      table.insert(entries, current)
      current = nil
    elseif current and not line:match("^%s+paths:") and not line:match("^%s+-") then
      current = current .. "\n" .. line:match("^%s*(.*)")
    end
  end
  if current then
    table.insert(entries, current)
  end
  return entries
end

local function parse_shell(lines)
  local entries = {}
  for _, line in ipairs(lines) do
    -- strip zsh extended history prefixes, keep bash lines as-is
    table.insert(entries, (line:gsub("^: %d+:%d+;", "")))
  end
  return entries
end

--- returns shell history commands, most recent first, deduplicated
--- @return table
function M.commands()
  for _, path in ipairs(candidates()) do
    if vim.fn.filereadable(path) == 1 then
      local lines = {}
      for line in io.lines(path) do
        table.insert(lines, line)
      end

      local is_fish = vim.fn.fnamemodify(path, ":t"):find("fish") ~= nil
      local entries = is_fish and parse_fish(lines) or parse_shell(lines)

      local seen = {}
      local commands = {}
      for i = #entries, 1, -1 do
        local entry = entries[i]
        if entry:match("%S") and not seen[entry] then
          seen[entry] = true
          table.insert(commands, entry)
        end
      end
      return commands
    end
  end
  return {}
end

--- opens a picker over shell history, calling on_choice with the selected command
--- @param on_choice function
function M.pick(on_choice)
  local commands = M.commands()
  if #commands == 0 then
    vim.notify("runner: no shell history found", vim.log.levels.WARN)
    return
  end

  if not pcall(require, "telescope.pickers") then
    vim.notify("runner: telescope not installed, using vim.ui.select", vim.log.levels.INFO)
    vim.ui.select(commands, { prompt = "Shell History: " }, function(command)
      if command then
        on_choice(command)
      end
    end)
    return
  end

  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  pickers.new({}, {
    prompt_title = "Shell History",
    finder = finders.new_table({ results = commands }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        local command = action_state.get_selected_entry()[1]
        actions.close(prompt_bufnr)
        if command then
          on_choice(command)
        end
      end)
      return true
    end,
  }):find()
end

return M
