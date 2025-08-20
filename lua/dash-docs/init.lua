--[[
  dash-docs.nvim

  A simple, fast, and dependency-free API library for browsing
  Dash and Zeal docsets within Neovim.
]]

-- EmmyLua annotations for type checking
---@class Dash.Config
---@field docsets_path? string Path to the docsets directory.

---@class Dash.Docset
---@field name string The name of the docset (e.g., "Lua 5.1")
---@field path string The absolute path to the .docset directory
---@field keyword string The keyword used for opening in Dash/Zeal
---@field family string The family name (usually same as keyword)

---@class Dash.SearchResult
---@field name string The name of the entry
---@field type string The type of the entry (e.g., "Function")
---@field path string The path to the HTML file within the docset
---@field docset Dash.Docset The docset this result belongs to

local util = require("dash-docs.util")

local M = {}

---@type Dash.Config
local config = {
  docsets_path = nil,
}

---@type table<string, Dash.Docset>
local available_docsets = {}

---@private
--- Scans for docsets and populates the available_docsets table.
---@param path string The path to scan.
local function scan_docsets(path)
  vim.loop.fs_scandir(path, function(err, dir)
    if err or not dir then
      vim.notify("Dash.nvim: Error scanning directory: " .. tostring(err), vim.log.levels.ERROR)
      return
    end

    local function next_entry()
      local name, type = dir:next()
      if not name then
        -- Finished scanning
        vim.schedule(function()
          vim.notify("Dash.nvim: Found " .. vim.tbl_count(available_docsets) .. " docsets.")
        end)
        return
      end

      if type == "directory" and name:match("%.docset$") then
        local docset_path = path .. "/" .. name
        local metadata = util.parse_info_plist(docset_path)
        if metadata then
          ---@type Dash.Docset
          local docset = {
            name = metadata.name,
            path = docset_path,
            keyword = metadata.keyword,
            family = metadata.family,
          }
          available_docsets[metadata.keyword] = docset
        end
      end

      -- Schedule the next iteration to avoid blocking
      vim.schedule(next_entry)
    end

    -- Start scanning
    next_entry()
  end)
end

--- Setup the dash.nvim module.
---@param user_config? Dash.Config
function M.setup(user_config)
  config = vim.tbl_deep_extend("force", config, user_config or {})

  local docsets_dir = config.docsets_path or util.get_default_docsets_path()

  if not docsets_dir or vim.fn.isdirectory(docsets_dir) == 0 then
    vim.notify("Dash.nvim: Docsets directory not found. Please configure it via setup({docsets_path = '...'})", vim.log.levels.WARN)
    return
  end

  config.docsets_path = docsets_dir
  -- Clear existing docsets if setup is called again
  available_docsets = {}
  scan_docsets(config.docsets_path)
end

--- Searches for a term in the docsets.
---@param query string The term to search for.
---@param docset_keywords? string[] An optional list of docset keywords to search in.
---@return Dash.SearchResult[]
function M.search(query, docset_keywords)
  local results = {}
  local search_targets = {}

  if docset_keywords and #docset_keywords > 0 then
    for _, keyword in ipairs(docset_keywords) do
      if available_docsets[keyword] then
        table.insert(search_targets, available_docsets[keyword])
      end
    end
  else
    -- No specific docsets requested, so search all of them.
    for _, docset in pairs(available_docsets) do
      table.insert(search_targets, docset)
    end
  end

  for _, docset in ipairs(search_targets) do
    local db_path = docset.path .. "/Contents/Resources/docSet.dsidx"
    local schema = util.get_schema(db_path)

    if schema then
      -- The `%%` escapes the `%` for string.format, and the outer `%` are for the LIKE clause.
      -- The query is also sanitized to prevent SQL injection via single quotes.
      local sanitized_query = query:gsub("'", "''")
      local sql = string.format("SELECT %s, %s, %s FROM searchIndex WHERE %s LIKE '%%%s%%' LIMIT 100;",
        schema.name, schema.type, schema.path, schema.name, sanitized_query)

      local lines = util.query_db(db_path, sql)
      if lines then
        for _, line in ipairs(lines) do
          local parts = vim.split(line, "|", true) -- `true` to allow empty fields
          if #parts == 3 then
            table.insert(results, {
              name = parts[1],
              type = parts[2],
              path = parts[3],
              docset = docset,
            })
          end
        end
      end
    end
  end

  return results
end

---@private
--- URL-encodes a string for use in URIs.
---@param str string
---@return string
local function url_encode(str)
    return str:gsub("([^%w _!~'()*.])", function(c)
        return string.format("%%%02X", string.byte(c))
    end):gsub(" ", "%%20")
end

--- Opens a search result in Dash or Zeal.
---@param result Dash.SearchResult
function M.open(result)
  local keyword = result.docset.keyword
  -- Some docsets have entries with slashes, which need to be encoded.
  -- The name itself might not be enough, the path is more reliable for some docsets (e.g., man pages).
  -- However, the `dash-plugin://` scheme works best with `query=NAME`.
  -- Let's stick to the name for now as it's the most common case.
  local query_str = result.name
  local uri = string.format("dash-plugin://keys=%s&query=%s", keyword, url_encode(query_str))

  local cmd
  if vim.fn.has("mac") == 1 then
    cmd = "open"
  elseif vim.fn.has("win32") == 1 then
    cmd = "start"
  else -- "unix"
    cmd = "xdg-open"
  end

  vim.fn.jobstart(string.format('%s "%s"', cmd, uri), { detach = true })
end

--- Returns the list of all available docsets.
---@return Dash.Docset[]
function M.get_docsets()
  local docset_list = {}
  for _, docset in pairs(available_docsets) do
    table.insert(docset_list, docset)
  end
  -- Sort by name for consistent ordering
  table.sort(docset_list, function(a, b) return a.name < b.name end)
  return docset_list
end

return M
