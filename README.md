# 🗑️ recycle-bin.yazi

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)
[![Yazi](https://img.shields.io/badge/Yazi-25.5%2B-blue?style=for-the-badge)](https://github.com/sxyazi/yazi)
[![GitHub stars](https://img.shields.io/github/stars/uhs-robert/recycle-bin.yazi?style=for-the-badge)](https://github.com/uhs-robert/recycle-bin.yazi/stargazers)
[![GitHub issues](https://img.shields.io/github/issues-raw/uhs-robert/recycle-bin.yazi?style=for-the-badge)](https://github.com/uhs-robert/recycle-bin.yazi/issues)

> [!WARNING]
> This is currently in development and not actually ready. Hoping to have it ready by September of 2025 if not earlier since I like to dumpster dive in my trash.

---

A minimal, fast **Recycle Bin** for the [Yazi](https://github.com/sxyazi/yazi) terminal file‑manager.

Browse your trash in style straight from the terminal. Select the files you want to restore, select files to permanently delete, or just empty the bin.

> [!NOTE]
>
> **Linux Only (for now!)**
>
> This plugin currently supports Linux only.
> If you're interested in helping add support for other platforms, check out the open issues:
>
> - [Add macOS support](https://github.com/uhs-robert/recycle-bin.yazi/issues/1)
> - [Add Windows support](https://github.com/uhs-robert/recycle-bin.yazi/issues/2)
>
> If you have some Lua experience (or want to learn), I’d be happy to walk you through integration and testing. Pull requests are welcome!

## 🧠 What it does under the hood

This plugin serves as a wrapper for the `trash-cli` command, integrating it seamlessly with Yazi.

## ✨ Features

## 📋 Requirements

| Software  | Minimum     | Notes                                   |
| --------- | ----------- | --------------------------------------- |
| Yazi      | `>=25.5.31` | untested on 25.6+                       |
| trash-cli | any         | `sudo dnf/apt/pacman install trash-cli` |

## 📦 Installation

Install the plugin via Yazi's package manager:

```sh
# via Yazi’s package manager
ya pack -a uhs-robert/recycle-bin
```

Then add the following to your `~/.config/yazi/init.lua` to enable the plugin with default settings:

```lua
require("recycle-bin"):setup()
```

## ⚙️ Configuration

To customize plugin behavior, you may pass a config table to `setup()` (default settings are displayed):

```lua
require("recycle-bin"):setup({
  -- Trash directory
  trash_dir = "~/.local/share/Trash/files/",

  -- Picker UI settings
  ui = {
    -- Maximum number of items to show in the menu picker.
    -- If the list exceeds this number, a different picker (like fzf) is used.
    menu_max = 15, -- Recommended: 10–20. Max: 36.

    -- Picker strategy:
    -- "auto": uses menu if items <= menu_max, otherwise fzf (if available) or a filterable list
    -- "fzf": always use fzf if available, otherwise fallback to a filterable list
    picker = "auto", -- "auto" | "fzf"
  },
})
```

## 🎹 Key Mapping

Add the following to your `~/.config/yazi/keymap.toml`. You can customize keybindings to your preference.

```toml
[mgr]
prepend_keymap = [

]
```

## 🚀 Usage
