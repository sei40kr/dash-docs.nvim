-- EmmyLua annotations
---@class Dash.Util
local M = {}

--- Returns the default path for Dash/Zeal docsets based on the OS.
---@return string?
function M.get_default_docsets_path()
  local home = os.getenv("HOME")
  if not home then
    -- Handle Windows case where HOME might not be set
    if vim.fn.has("win32") == 1 then
      local userprofile = os.getenv("USERPROFILE")
      if not userprofile then return nil end
      home = userprofile
    else
      return nil
    end
  end

  local paths
  if vim.fn.has("mac") == 1 then
    paths = {
      home .. "/Library/Application Support/Dash/DocSets", -- Dash
      home .. "/Library/Application Support/Zeal/Zeal/docsets", -- Zeal on Mac
    }
  elseif vim.fn.has("win32") == 1 then
    local appdata = os.getenv("APPDATA")
    local local_appdata = os.getenv("LOCALAPPDATA")
    paths = {}
    if appdata then
        table.insert(paths, appdata .. "\\Zeal\\Zeal\\docsets")
    end
    if local_appdata then
        table.insert(paths, local_appdata .. "\\Zeal\\Zeal\\docsets")
    end
  else -- Linux and other Unix
    paths = {
      home .. "/.local/share/Zeal/Zeal/docsets",
    }
  end

  for _, path in ipairs(paths) do
    if vim.fn.isdirectory(path) == 1 then
      return path
    end
  end

  return nil
end

--- Parses the Info.plist file to get docset metadata.
--- Uses simple string matching to avoid a full XML parser dependency.
---@param docset_path string Path to the *.docset directory.
---@return { name: string, keyword: string, family: string }?
function M.parse_info_plist(docset_path)
    local plist_path = docset_path .. "/Contents/Info.plist"
    if vim.fn.filereadable(plist_path) == 0 then
        return nil
    end

    local lines = vim.fn.readfile(plist_path)
    local content = table.concat(lines, "\n")

    local _, _, name = string.find(content, "<key>CFBundleName</key>%s*<string>([^<]+)</string>")
    local _, _, keyword = string.find(content, "<key>DashDocSetKeyword</key>%s*<string>([^<]+)</string>")
    local _, _, family = string.find(content, "<key>DashDocSetFamily</key>%s*<string>([^<]+)</string>")

    if name and keyword then
        return {
            name = name,
            keyword = keyword,
            family = family or keyword, -- Fallback to keyword if family is not present
        }
    end
    return nil
end


--- Queries a docset's SQLite database using the sqlite3 CLI.
---@param db_path string Path to the docset's SQLite database.
---@param query string The SQL query to execute.
---@return string[]? lines The query result, one line per row, columns separated by '|'.
function M.query_db(db_path, query)
    if vim.fn.executable("sqlite3") == 0 then
        vim.notify("Dash.nvim: `sqlite3` command-line tool not found in your PATH.", vim.log.levels.ERROR)
        return nil
    end

    if vim.fn.filereadable(db_path) == 0 then
        return nil -- Don't show error, might be an invalid docset
    end

    local cmd = string.format("sqlite3 -readonly -separator '|' %s %s", vim.fn.shellescape(db_path), vim.fn.shellescape(query))
    local result = vim.fn.system(cmd)

    if vim.v.shell_error ~= 0 then
        vim.notify("Dash.nvim: sqlite3 query failed.", vim.log.levels.WARN)
        return nil
    end

    return vim.split(result, "\n")
end

-- Cache for schema to avoid repeated PRAGMA queries
local schema_cache = {} -- map from db_path to schema table

--- Determines the column names for the searchIndex table.
---@param db_path string Path to the SQLite database.
---@return {name: string, type: string, path: string}?
function M.get_schema(db_path)
    if schema_cache[db_path] then
        return schema_cache[db_path]
    end

    local pragma_query = "PRAGMA table_info(searchIndex);"
    local lines = M.query_db(db_path, pragma_query)
    if not lines or #lines == 0 then return nil end

    local has_z_prefix = false
    for _, line in ipairs(lines) do
        -- line format is: cid|name|type|notnull|dflt_value|pk
        local parts = vim.split(line, "|")
        if #parts >= 2 then
            local col_name = parts[2]
            if col_name == "zName" then
                has_z_prefix = true
                break
            end
        end
    end

    local schema
    if has_z_prefix then
        schema = { name = "zName", type = "zType", path = "zPath" }
    else
        schema = { name = "name", type = "type", path = "path" }
    end

    schema_cache[db_path] = schema
    return schema
end

return M
