# dash-docs.nvim

A Neovim library that provides the simple Lua APIs for searching, viewing, and
managing [Dash](https://kapeli.com/dash) or [Zeal](https://zealdocs.org) docsets.
Ported from [dash-docs-el/dash-docs](https://github.com/dash-docs-el/dash-docs/).

## Requirements

- Neovim 0.9 (may also work on lower versions, but I haven't tested)
- [sqlite.lua](https://github.com/kkharji/sqlite.lua)
  - Ensure you have `sqlite3` installed

## Usage

```lua
local Docset = require("dash-docs.docset")

local docset, err = Docset.open("Neovim", "/path/to/docsets_directory")
if err ~= nil then
    vim.notify(err, vim.log.levels.ERROR)
    return
end

local items, err = docset:search("vim.api")

if err ~= nil then
    vim.notify(err, vim.log.levels.ERROR)
    return
end

items[0]
-- { {
--     item_type = "Function",
--     name = "vim.api",
--     path = "lua.html#vim.api"
--   } }
```
