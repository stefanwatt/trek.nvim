
# trek.nvim

Basically took [mini.files](https://github.com/echasnovski/mini.files) and changed what I don't like about it.

---

## ✨ Features

- **Miller Column Navigation**: I loved this as soon as I first tried it
- **Static Layout**: I prefer a static, 3-column, full-height layout like in ranger
- **LSP Integration**: Took lsp renaming functionality from [oil.nvim](https://github.com/stevearc/oil.nvim) and integrated it

---

## ⚙️ Configuration

Below is the default configuration for `trek.nvim`:

```lua
config = {
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
To customize these settings, call the setup with your configuration.

---

## 🚀 Usage

### Open `trek.nvim` at the current path

You can open `trek.nvim` at the current path with this command:

```lua
require("trek").open(vim.api.nvim_buf_get_name(0))
```

The `open` function for `trek.nvim` can be used to open the directory of any given file path.

---

## 🔑 Default Keymaps
- **Close**: `q`
- **Go into directory**: `<Right>`
- **Go out of directory**: `<Left>`
- **Synchronize view**: `=`

---

## 📦 Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
use {
  "stefanwatt/trek.nvim",
  
  dependencies = {
    "nvim-tree/nvim-web-devicons",
  },
  lazy = false,
  keys = {
    {
      "<leader>e",
      mode = { "n" },
      function()
        require("trek").open(vim.api.nvim_buf_get_name(0))
      end,
      desc = "File Explorer",
    },
  },
  config = function()
    require("trek").setup({
      keymaps = {
        close = "q",
        go_in = "<Right>",
        go_out = "<Left>",
        synchronize = "=",
      }
    });
  end
}
```

---


### 🙏 Special Thanks

This project is inspired by and includes code from:
- [mini.files](https://github.com/echasnovski/mini.nvim/tree/main/readmes/mini-files.md) — for large part of the code, especially filesystem
- [oil.nvim](https://github.com/stevearc/oil.nvim) — for LSP renaming functionality
