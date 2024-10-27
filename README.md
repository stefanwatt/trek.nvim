
# trek.nvim
<div align="center"><p>
    <a href="https://github.com/stefanwatt/trek.nvim/releases/latest">
      <img alt="Latest release" src="https://img.shields.io/github/v/release/stefanwatt/trek.nvim?style=for-the-badge&logo=starship&color=C9CBFF&logoColor=D9E0EE&labelColor=302D41&include_prerelease&sort=semver" />
    </a>
    <a href="https://github.com/stefanwatt/trek.nvim/pulse">
      <img alt="Last commit" src="https://img.shields.io/github/last-commit/stefanwatt/trek.nvim?style=for-the-badge&logo=starship&color=8bd5ca&logoColor=D9E0EE&labelColor=302D41"/>
    </a>
    <a href="https://github.com/stefanwatt/trek.nvim/blob/main/LICENSE">
      <img alt="License" src="https://img.shields.io/github/license/stefanwatt/trek.nvim?style=for-the-badge&logo=starship&color=ee999f&logoColor=D9E0EE&labelColor=302D41" />
    </a>
    <a href="https://github.com/stefanwatt/trek.nvim/stargazers">
      <img alt="Stars" src="https://img.shields.io/github/stars/stefanwatt/trek.nvim?style=for-the-badge&logo=starship&color=c69ff5&logoColor=D9E0EE&labelColor=302D41" />
    </a>
    <a href="https://github.com/stefanwatt/trek.nvim/issues">
      <img alt="Issues" src="https://img.shields.io/github/issues/stefanwatt/trek.nvim?style=for-the-badge&logo=bilibili&color=F5E0DC&logoColor=D9E0EE&labelColor=302D41" />
    </a>
    <a href="https://github.com/stefanwatt/trek.nvim">
      <img alt="Repo Size" src="https://img.shields.io/github/repo-size/stefanwatt/trek.nvim?color=%23DDB6F2&label=SIZE&logo=codesandbox&style=for-the-badge&logoColor=D9E0EE&labelColor=302D41" />
    </a>
   </div>

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
{
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
