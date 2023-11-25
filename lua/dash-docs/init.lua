local M = {}

-- Find the directory for Dash official docsets.
---@return string? # Returns the path to the directory on success. Returns nil on failure.
function M.find_official_docsets_dir()
  local paths = {
    vim.fn.expand("~/Library/Application Support/Dash/DocSets"),
    vim.fn.expand("$XDG_DATA_HOME/Zeal/Zeal/docsets"),
  };

  for _, path in ipairs(paths) do
    if vim.fn.isdirectory(path) == 1 then
      return path
    end
  end
end

-- Find the directory for Dash user-contributed docsets.
---@return string? # Returns the path to the directory on success. Returns nil on failure.
function M.find_user_docsets_dir()
  local paths = {
    vim.fn.expand("~/Library/Application Support/Dash/User Contributed"),
    vim.fn.expand("$XDG_DATA_HOME/Zeal/Zeal/docsets"),
  };

  for _, path in ipairs(paths) do
    if vim.fn.isdirectory(path) == 1 then
      return path
    end
  end
end

return M
