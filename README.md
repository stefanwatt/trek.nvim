
# trek.nvim

`trek.nvim` is a modern and minimalistic file explorer plugin for Neovim. It combines miller columns from [mini.files](https://github.com/echasnovski/mini.nvim/tree/main/readmes/mini-files.md) with a static-width, static-column layout inspired by [ranger](https://github.com/ranger/ranger). Designed to provide a streamlined navigation experience, `trek.nvim` is simple in both its UI and codebase, focusing on a fluid file-browsing experience without unnecessary clutter.

---

## ✨ Features

- **Miller Column Navigation**: Effortlessly navigate directories with a clean and organized column view.
- **Static Layout**: A fullscreen, consistent-width layout with a fixed number of columns for a smooth file-browsing experience.
- **Simplified Codebase**: Removed confirmation popups and additional prompts for faster navigation.
- **LSP Integration**: Full support for LSP rename actions, seamlessly integrated from [oil.nvim](https://github.com/stevearc/oil.nvim).

Special thanks to [mini.files](https://github.com/echasnovski/mini.nvim/tree/main/readmes/mini-files.md) and [oil.nvim](https://github.com/stevearc/oil.nvim) for inspiration and source code contributions.

---

## ⚙️ Configuration

Below is the default configuration for `trek.nvim`:

```lua
---@class trek.LSPConfig
---@field timeout_ms integer
---@field autosave_changes boolean
---
---@class trek.KeymapsConfig
---@field close string
---@field go_in string
---@field go_out string
---@field synchronize string
---
---@class trek.Config
---@field keymaps trek.KeymapsConfig
---@field lsp trek.LSPConfig
M.config = {
  lsp = {
    timeout_ms = 500,
    autosave_changes = true,
  },
  keymaps = {
    close = "q",
    go_in = "<Right>",
    go_out = "<Left>",
    synchronize = "=",
  },
}
```

To customize these settings, set up `trek.nvim` with your preferred configurations.

---

## 🚀 Usage

### Open `trek.nvim` at the current path

You can open `trek.nvim` at the current path with this simple command:

```lua
require("trek").open(vim.api.nvim_buf_get_name(0))
```

### `open` Function

The `open` function for `trek.nvim` can be used to open the directory of any given file path:

```lua
---@param path string
M.open = function(path)
  local dir = fs.get_directory_of_path(path)
  explorer.open(dir)
end
```

---

## 🔑 Keybindings

Default keybindings provide intuitive and quick file navigation:

- **Close**: `q`
- **Go into directory**: `<Right>`
- **Go out of directory**: `<Left>`
- **Synchronize view**: `=`

---

## 📦 Installation

Using [packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use {
  "yourusername/trek.nvim",
  config = function()
    require("trek").setup {
      -- Your custom settings here
    }
  end
}
```

---

## 📜 License

`trek.nvim` is licensed under the MIT License.

--- 

### 🙏 Special Thanks

This project is inspired by and includes code from:
- [mini.files](https://github.com/echasnovski/mini.nvim/tree/main/readmes/mini-files.md) — for miller column structure.
- [oil.nvim](https://github.com/stevearc/oil.nvim) — for LSP renaming functionality.
