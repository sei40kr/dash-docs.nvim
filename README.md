# dash-docs.nvim

A simple, fast, and dependency-free API library for browsing [Dash](https://kapeli.com/dash) and [Zeal](https://zealdocs.org/) docsets within Neovim.

This plugin provides a Lua API to find, search, and open documentation from your installed docsets. It is designed to be a backend for other plugins, particularly fuzzy finders like [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim).

## Features

- **Truly Dependency-Free:** Works out of the box with a modern Neovim. It does **not** require any external Lua libraries like `sqlite.lua`. It only uses the `sqlite3` command-line tool, which is pre-installed on macOS and available in most Linux/Windows package managers.
- **Asynchronous:** All file system operations are handled asynchronously to prevent UI blocking, ensuring Neovim remains responsive even with many docsets.
- **Automatic Docset Detection:** Automatically finds your Dash or Zeal docsets on macOS, Linux, and Windows.
- **Universal Schema Support:** Correctly handles both old and new docset database schemas (i.e., with or without the `z` column prefix).
- **Simple, Functional API:** A minimal set of functions to integrate with any frontend.

## Requirements

- Neovim >= 0.8
- `sqlite3` in your system's `PATH`.

## Installation

Install with your favorite plugin manager.

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{ 'your-github-username/dash-docs.nvim' } -- Replace with the actual repository path
```

### [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use { 'your-github-username/dash-docs.nvim' } -- Replace with the actual repository path
```

## Setup and Configuration

Call the `setup` function somewhere in your Neovim configuration (`init.lua`). The setup function will automatically scan for docsets in the background.

```lua
require('dash-docs').setup({
  -- Optional: specify the path to your docsets directory.
  -- If nil, the plugin will try to auto-detect it.
  -- docsets_path = '/path/to/your/docsets',
})
```

## API

The plugin provides a simple, functional API.

### `get_docsets()`

Returns a list of all available docsets.

- **Returns:** `Dash.Docset[]` - A list of docset objects, sorted by name.

Each `Docset` object has the following shape:
```lua
{
  name = "Lua 5.1",         -- string: The display name
  keyword = "lua",          -- string: The unique keyword
  family = "lua",           -- string: The family name
  path = "/path/to/Lua.docset" -- string: The absolute path
}
```

### `search(query, [docset_keywords])`

Searches for a `query` within your docsets.

- **`query`** (`string`): The term to search for.
- **`docset_keywords`** (`string[]`, optional): A list of docset keywords (e.g., `{'lua', 'python'}`) to search in. If omitted, searches all available docsets.
- **Returns:** `Dash.SearchResult[]` - A list of search result objects.

Each `SearchResult` object has the following shape:
```lua
{
  name = "string.gsub", -- string: The name of the entry
  type = "Function",    -- string: The type of entry
  path = "index.html#string.gsub", -- string: The path inside the docset
  docset = { ... } -- Dash.Docset: The docset the result belongs to
}
```

### `open(result)`

Opens a search result in Dash or Zeal.

- **`result`** (`Dash.SearchResult`): A search result object returned from `search()`.

## Example: Telescope Integration

Here is an example of how to create a Telescope picker to search your docsets.

```lua
-- your-neovim-config/init.lua or a file sourced from it

-- First, make sure you setup the plugin
require('dash-docs').setup()

-- Now, create the Telescope picker
local function create_dash_picker()
  local dash = require('dash-docs')
  local actions = require('telescope.actions')
  local action_state = require('telescope.actions.state')
  local finders = require('telescope.finders')
  local pickers = require('telescope.pickers')
  local conf = require('telescope.config').values

  pickers.new({}, {
    prompt_title = 'Search Dash/Zeal',
    finder = finders.new_dynamic({
      fn = function(prompt)
        if prompt == nil or prompt == '' then
          return
        end
        -- Asynchronously search all docsets for the prompt
        return dash.search(prompt)
      end,
      entry_maker = function(entry)
        return {
          value = entry,
          display = string.format('[%s] %s', entry.docset.name, entry.name),
          ordinal = entry.name,
        }
      end,
    }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        if selection then
          dash.open(selection.value)
        end
      end)
      return true
    end,
  }):find()
end

-- You can then map this to a key
vim.keymap.set('n', '<leader>fd', create_dash_picker, { noremap = true, silent = true, desc = 'Find in Dash' })
```
