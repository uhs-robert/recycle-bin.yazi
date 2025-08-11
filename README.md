# 🗑️ recycle-bin.yazi

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)
[![Yazi](https://img.shields.io/badge/Yazi-25.5%2B-blue?style=for-the-badge)](https://github.com/sxyazi/yazi)
[![GitHub stars](https://img.shields.io/github/stars/uhs-robert/recycle-bin.yazi?style=for-the-badge)](https://github.com/uhs-robert/recycle-bin.yazi/stargazers)
[![GitHub issues](https://img.shields.io/github/issues-raw/uhs-robert/recycle-bin.yazi?style=for-the-badge)](https://github.com/uhs-robert/recycle-bin.yazi/issues)

A fast, minimal **Recycle Bin** for the [Yazi](https://github.com/sxyazi/yazi) terminal file‑manager.

Browse, restore, or permanently delete trashed files without leaving your terminal. Includes age-based cleanup and bulk actions.

<https://github.com/user-attachments/assets/1f7ab9b2-33e3-4262-94c5-b27ad9dc142e>

> [!NOTE]
>
> **Linux Only**
>
> This plugin currently supports Linux only.

## 🧠 What it does under the hood

This plugin serves as a wrapper for the [trash-cli](https://github.com/andreafrancia/trash-cli) command, integrating it seamlessly with Yazi.

## ✨ Features

- **📂 Browse trash**: Navigate to trash directory directly in Yazi
- **🔄 Restore files**: Bulk restore selected files from trash to their original locations
- **🗑️ Empty trash**: Clear entire trash with confirmation dialog
- **📅 Empty by days**: Remove trash items older than specified number of days
- **❌ Permanent delete**: Bulk delete selected files from trash permanently
- **🔧 Configurable**: Customize trash directory

## 📋 Requirements

| Software  | Minimum     | Notes                                   |
| --------- | ----------- | --------------------------------------- |
| Yazi      | `>=25.5.31` | untested on 25.6+                       |
| trash-cli | any         | `sudo dnf/apt/pacman install trash-cli` |

The plugin uses the following trash-cli commands: `trash-list`, `trash-empty`, `trash-restore`, and `trash-rm`.

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
  ], run = "plugin recycle-bin empty", desc = "Empty Trash" },

  # Delete selected items from trash
  { on = [
    "R",
    "d",
  ], run = "plugin recycle-bin delete", desc = "Delete from Trash" },

  # Empty trash by days since deleted
  { on = [
    "R",
    "D",
  ], run = "plugin recycle-bin emptyDays", desc = "Empty by days deleted" },

  # Restore selected items from trash
  { on = [
    "R",
    "r",
  ], run = "plugin recycle-bin restore", desc = "Restore from Trash" },
]
```

## 🚀 Usage

### Basic Operations

1. **Navigate to trash**: Press `gt` or `Ro` to go directly to the trash directory
2. **Restore files**: Select files in trash using Yazi's native selection and press `Rr` to restore them
3. **Delete permanently**: Select files in trash and press `Rd` to delete them permanently
4. **Empty trash**: Press `Re` to empty the entire trash bin (with confirmation)
5. **Empty by age**: Press `RD` to empty trash items older than specified days (defaults to 30 days)

> [!TIP]
> Use Yazi's visual selection (`v` or `V` followed by `ESC` to select items) or toggle select (press `Space` on individual files) to select multiple files from the Trash before restoring or deleting
>
> The plugin will show a confirmation dialog for destructive operations

## 🛠️ Troubleshooting

### Common Issues

**"trashcli not found" error:**

- Ensure trash-cli is installed: `sudo dnf/apt/pacman install trash-cli`
- Verify installation: `trash-list --version`
- Check if trash-cli commands are in your PATH

**"Trash directory not found" error:**

- The default trash directory is `~/.local/share/Trash/`
- Create it manually if it doesn't exist: `mkdir -p ~/.local/share/Trash/{files,info}`
- Or customize the path in your configuration

**"No files selected" warning:**

- Make sure you have files selected in Yazi before running restore/delete operations
- Use `Space` to select files or `v`/`V` for visual selection mode

## 💡 Recommendations

### Companion Plugin

For an even better trash management experience, pair this plugin with:

**[restore.yazi](https://github.com/boydaihungst/restore.yazi)** - Undo your delete history by your latest deleted files/folders

This companion plugin adds an "undo" feature that lets you press `u` to instantly restore the last deleted file. You can keep hitting `u` repeatedly to step through your entire delete history, making accidental deletions a thing of the past.

**Perfect combination:** Use `restore.yazi` for quick single-file undos and `recycle-bin.yazi` for comprehensive trash management and bulk operations.
