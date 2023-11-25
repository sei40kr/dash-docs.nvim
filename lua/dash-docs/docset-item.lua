---@class DocsetItem
---@field name string
---@field item_type string
---@field path string

local DocsetItem = {}

-- Create a new DocsetItem.
---@param opts { name: string, item_type: string, path: string }
---@return DocsetItem
function DocsetItem.new(opts)
  return {
    name = opts.name,
    item_type = opts.item_type,
    path = opts.path,
  }
end

return DocsetItem
