--- @enum docset_type
local DOCSET_TYPE = {
  dash = 0,
  zdash = 1,
}

---@class Docset
---@field name string
---@field docset_path string
---@field db unknown
---@field docset_type docset_type
local Docset = {}

-- Open the docset with the given name.
---@param name string # The name of the docset to open
---@param docsets_dir string # The path to the docsets directory
---@return Docset?, string? # Returns a Docset as the 1st value and nil as the 2nd value on success. Returns nil as the 1st value and an error message as the 2nd value on failure.
function Docset.open(name, docsets_dir)
  local docset_path = vim.fn.globpath(docsets_dir, "*/" .. name .. ".docset", true)

  if docset_path == "" then
    return nil, "Docset not found: " .. name
  end

  local db_path = docset_path .. "/Contents/Resources/docSet.dsidx"

  if vim.fn.filereadable(db_path) == 0 then
    return nil, "Docset database not found or not readable: " .. db_path
  end

  local db = require("sqlite").new(db_path, { open_mode = "ro" })

  db:open()

  local rows = db:eval([[
    SELECT
      count(1) AS count
    FROM
      sqlite_master
    WHERE
      type = 'table'
      AND name = 'searchIndex'
    LIMIT 1
  ]])
  local docset_type

  if rows == false then
    db:close()
    return "Error checking docset type: " .. rows, nil
  end

  if 0 < #rows and rows[1].count == 1 then
    docset_type = DOCSET_TYPE.dash
  else
    docset_type = DOCSET_TYPE.zdash
  end

  local o = {
    name = name,
    docset_path = docset_path,
    db = db,
    docset_type = docset_type,
  }

  setmetatable(o, { __index = Docset })

  return o, nil
end

-- Search the docset for the given pattern.
---@param pattern string # The pattern to search for
---@return DocsetItem[]?, string? # Returns a list of DocsetItem as the 1st value and nil as the 2nd value on success. Returns nil as the 1st value and an error message as the 2nd value on failure.
function Docset:search(pattern)
  if self.db:isclose() then
    return nil, "Docset not open: " .. self.name
  end

  local DocsetItem = require("dash-docs.docset-item")
  local items
  pattern = pattern:gsub("([%%_])", "\\%1")

  if self.docset_type == DOCSET_TYPE.dash then
    local rows = self.db:eval([[
      SELECT
        type,
        name,
        path
      FROM
        searchIndex
      WHERE
        name LIKE ? ESCAPE '\'
      ORDER BY
        length(name),
        lower(name)
      LIMIT 1000
    ]], { "%" .. pattern .. "%" })

    if rows == false then
      return nil, "Error searching docset: " .. rows
    end
    if rows == true then
      rows = {}
    end

    items = vim.tbl_map(function(row)
      return DocsetItem.new({
        name = row.name,
        item_type = row.type,
        path = row.path,
      })
    end, rows)
  elseif self.docset_type == DOCSET_TYPE.zdash then
    -- TODO: Implement Zdash docset type support
    return nil, "Zdash docset type not yet supported"
  end

  return items, nil
end

function Docset:close()
  self.db:close()
end

return Docset
