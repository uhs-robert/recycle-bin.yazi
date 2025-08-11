# 🗑️ recycle-bin.yazi

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)
[![Yazi](https://img.shields.io/badge/Yazi-25.5%2B-blue?style=for-the-badge)](https://github.com/sxyazi/yazi)
[![GitHub stars](https://img.shields.io/github/stars/uhs-robert/recycle-bin.yazi?style=for-the-badge)](https://github.com/uhs-robert/recycle-bin.yazi/stargazers)
[![GitHub issues](https://img.shields.io/github/issues-raw/uhs-robert/recycle-bin.yazi?style=for-the-badge)](https://github.com/uhs-robert/recycle-bin.yazi/issues)

A minimal and fast **Recycle Bin** for the [Yazi](https://github.com/sxyazi/yazi) terminal file‑manager.

Browse and manage your Trash straight from the terminal. Use this plugin to open your Trash and then select the files you want to restore or permanently delete. You may also remotely remove all files from the trash or only remove files deleted `<days>` ago.

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

This plugin serves as a wrapper for the [trash-cli](https://github.com/andreafrancia/trash-cli) command, integrating it seamlessly with Yazi.

## ✨ Features

- **📂 Browse trash**: Navigate to trash directory directly in Yazi
- **🔄 Restore files**: Bulk restore selected files from trash to their original locations
- **🗑️ Empty trash**: Clear entire trash with confirmation dialog
- **📅 Empty by days**: Remove trash items older than specified number of days
- **❌ Permanent delete**: Delete selected files from trash permanently
- **🔧 Configurable**: Customize trash directory

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
  trash_dir = "~/.local/share/Trash/",
})
```

## 🎹 Key Mapping

Add the following to your `~/.config/yazi/keymap.toml`. You can customize keybindings to your preference.

```toml
[mgr]
prepend_keymap = [
  # Go to Trash directory
  { on = [
    "g",
    "t",
  ], run = "plugin recycle-bin open", desc = "Go to Trash" },


  # Open the trash
  { on = [
    "R",
    "o",
  ], run = "plugin recycle-bin open", desc = "Open Trash" },

  # Empty the trash
  { on = [
    "R",
    "e",
  ], run = "plugin recycle-bin empty", desc = "Empty trash" },

  # Delete selected items from trash
  { on = [
    "R",
    "d",
  ], run = "plugin recycle-bin delete", desc = "Delete from trash" },

  # Empty trash by days since deleted
  { on = [
    "R",
    "D",
  ], run = "plugin recycle-bin emptyDays", desc = "Empty by days deleted" },

  # Restore selected items from trash
  { on = [
    "R",
    "r",
  ], run = "plugin recycle-bin restore", desc = "Restore from trash" },
]
```

## 🚀 Usage

### Basic Operations

1. **Navigate to trash**: Press `gt` or `Ro` to go directly to the trash directory
2. **Restore files**: Select files in trash using Yazi's native selection and press `Rr` to restore them
3. **Delete permanently**: Select files in trash and press `Rd` to delete them permanently
4. **Empty trash**: Press `Re` to empty the entire trash bin (with confirmation)
5. **Empty by age**: Press `RD` to empty trash items older than specified days

### Tips

- Use Yazi's visual selection (`v` or `V`) or toggle selection (press `Space` on files) to select multiple files from the Trash before restoring or deleting
- The plugin will show a confirmation dialog for destructive operations
