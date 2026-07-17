<p align="center">
  <img
    src="https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/svg/1f5d1.svg"
    width="128" height="128" alt="Trash emoji" />
</p>
<h1 align="center">recycle-bin.yazi</h1>

<p align="center">
  <a href="https://github.com/uhs-robert/recycle-bin.yazi/stargazers"><img src="https://img.shields.io/github/stars/uhs-robert/recycle-bin.yazi?colorA=192330&colorB=khaki&style=for-the-badge&cacheSeconds=4300"></a>
  <a href="https://github.com/sxyazi/yazi" target="_blank" rel="noopener noreferrer"><img alt="Yazi 0.25+" src="https://img.shields.io/badge/Yazi-0.25%2B-blue?style=for-the-badge&cacheSeconds=4300&labelColor=192330" /></a>
  <a href="https://github.com/uhs-robert/recycle-bin.yazi/issues"><img src="https://img.shields.io/github/issues/uhs-robert/recycle-bin.yazi?colorA=192330&colorB=skyblue&style=for-the-badge&cacheSeconds=4300"></a>
  <a href="https://github.com/uhs-robert/recycle-bin.yazi/contributors"><img src="https://img.shields.io/github/contributors/uhs-robert/recycle-bin.yazi?colorA=192330&colorB=8FD1C7&style=for-the-badge&cacheSeconds=4300"></a>
  <a href="https://github.com/uhs-robert/recycle-bin.yazi/network/members"><img src="https://img.shields.io/github/forks/uhs-robert/recycle-bin.yazi?colorA=192330&colorB=CFA7FF&style=for-the-badge&cacheSeconds=4300"></a>
</p>

<p align="center">
A blazing fast, minimal <strong>Recycle Bin</strong> for the <a target="_blank" rel="noopener noreferrer" href="https://github.com/sxyazi/yazi">Yazi</a> terminal file‑manager.
</p>

## 🕶️ What does it do?

Browse, restore, or permanently delete trashed files without leaving your terminal. Includes age-based cleanup and bulk actions.

<https://github.com/user-attachments/assets/1f7ab9b2-33e3-4262-94c5-b27ad9dc142e>

> [!NOTE]
>
> **Cross-Platform Support**
>
> This plugin supports Linux and macOS systems.
>
> On macOS, this plugin uses trash-cli's Freedesktop-spec trash (`~/.local/share/Trash`), **not** the native Finder Trash (`~/.Trash`). trash-cli's maintainer has confirmed it will likely never support the proprietary macOS Trash. See [Configuration](#️-configuration) and [Key Mapping](#-key-mapping) for the required macOS setup.

## 🧠 What it does under the hood

This plugin serves as a wrapper for the [trash-cli](https://github.com/andreafrancia/trash-cli) command, integrating it seamlessly with Yazi.

## ✨ Features

- **📂 Browse trash**: Navigate to trash directory directly in Yazi
- **🔄 Restore files**: Bulk restore selected files from trash to their original locations
  - **⚠️ Conflict resolution**: Intelligent handling when restored files already exist at destination
  - **🛡️ Safety dialogs**: Preview conflicts with skip/overwrite options before restoration
- **🗑️ Empty trash**: Clear entire trash with detailed file previews and confirmation dialog
- **📅 Empty by days**: Remove trash items older than specified number of days with size information
- **❌ Permanent delete**: Bulk delete selected files from trash permanently
- **🔧 Configurable**: Customize trash directory

## 📋 Requirements

| Software  | Minimum     | Notes                                                                                     |
| --------- | ----------- | ----------------------------------------------------------------------------------------- |
| Yazi      | `>=25.5.31` | untested on 25.6+                                                                         |
| trash-cli | any         | **Linux**: `sudo dnf/apt/pacman install trash-cli`<br>**macOS**: `brew install trash-cli` |

The plugin uses the following trash-cli commands: `trash-list`, `trash-empty`, `trash-restore`, and `trash-rm`.

> [!IMPORTANT]
> **macOS only:** yazi's default delete action sends files to the native Finder Trash (`~/.Trash`), which trash-cli cannot read (see [Cross-Platform Support](#-what-does-it-do)). For this plugin to see files you delete, you must also rebind your delete key to trash-cli's own `trash-put` instead of yazi's built-in trash action — see [Key Mapping](#-key-mapping).

## 📦 Installation

Install the plugin via Yazi's package manager:

```sh
# via Yazi’s package manager
ya pkg add uhs-robert/recycle-bin
```

Then add the following to your `~/.config/yazi/init.lua` to enable the plugin with default settings:

```lua
require("recycle-bin"):setup()
```

## ⚙️ Configuration

The plugin automatically discovers your system's trash directories using `trash-list --trash-dirs`. If you need to customize the behavior, you can pass a config table to `setup()`:

```lua
require("recycle-bin"):setup({
  -- Optional: Override automatic trash directory discovery
  -- trash_dir = "~/.local/share/Trash/",  -- Uncomment to use specific directory
})
```

> [!NOTE]
> The plugin supports multiple trash directories and will prompt you to choose which one to use if multiple are found.

## 🎹 Key Mapping

### 🗝️ Recommended: Preset

Add this to your `~/.config/yazi/keymap.toml` (substitute `on  = ["R","b"]` with your keybind preference):

```toml
[mgr]
prepend_keymap = [
  { on = ["R","b"], run = "plugin recycle-bin",              desc = "Open Recycle Bin menu" },
]
```

The `R b` menu provides access to all trash management functions:

- `o` → Open Trash
- `r` → Restore from Trash
- `d` → Delete from Trash
- `e` → Empty Trash
- `D` → Empty by Days

> [!TIP]
> `recycle-bin.yazi` uses the [array form for its keymap example](https://yazi-rs.github.io/docs/configuration/keymap).
> You must pick **only one style** per file; mixing with `[[mgr.prepend_keymap]]` will fail.
>
> **Also note:** some plugins may suggest binding a bare key like `on = "R"`,
> which blocks all `R <key>` chords (including `R b`). Change those to chords
> (e.g. `["R","r"]`) or choose a different non-conflicting prefix.

---

### 🛠️ Alternative: Custom direct keybinds

If you prefer direct keybinds, you may also set your own using our API. Here are the available options:

```toml
[mgr]
prepend_keymap = [
  { on = ["R","o"], run = "plugin recycle-bin -- open",        desc = "Open Trash" },
  { on = ["R","e"], run = "plugin recycle-bin -- empty",       desc = "Empty Trash" },
  { on = ["R","D"], run = "plugin recycle-bin -- emptyDays",   desc = "Empty by days deleted" },
  { on = ["R","d"], run = "plugin recycle-bin -- delete",      desc = "Delete from Trash" },
  { on = ["R","r"], run = "plugin recycle-bin -- restore",     desc = "Restore from Trash" },
]
```

> [!IMPORTANT]
> Remember that you are the only one who is responsible for managing and resolving your keybind conflicts.

---

### 🍎 macOS: Rebind Delete to trash-cli

yazi's default `d`/`D` delete keys move files to the native Finder Trash (`~/.Trash`), which trash-cli cannot read. To keep deletes and this plugin pointed at the same trash, override delete on macOS to call `trash-put` directly:

```toml
[mgr]
prepend_keymap = [
  { on = "d", run = "shell 'trash-put \"$@\"' --confirm", desc = "Trash (trash-cli)" },
]
```

This replaces yazi's built-in trash action with trash-cli's, so files land in `~/.local/share/Trash` where `recycle-bin.yazi` can browse, restore, and empty them. They will no longer appear in Finder's Trash.

## 🚀 Usage

### 📝 Example using the recommended preset

- **Recycle Bin Menu (`R b`):** Opens an interactive menu with all trash management options
  - **Open Trash (`o`):** Navigate to trash directory directly in Yazi
  - **Restore from Trash (`r`):** Bulk restore selected files from trash to their original locations. The plugin automatically detects conflicts when files already exist at the original location and prompts you to skip or overwrite conflicting files with detailed information.
  - **Delete from Trash (`d`):** Permanently delete selected files from trash. Shows confirmation dialog before deletion.
  - **Empty Trash (`e`):** Clear entire trash with detailed file previews including names, sizes, and deletion dates before confirmation.
  - **Empty by Days (`D`):** Remove trash items older than specified number of days (defaults to 30 days). Displays filtered list with file details and total size information.

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

- The plugin automatically discovers trash directories using `trash-list --trash-dirs`
- If no directories are found, create the standard location:
  - **Linux and macOS**: `mkdir -p ~/.local/share/Trash/{files,info}`
- You can also specify a custom path in your configuration

**"No files selected" warning:**

- Make sure you have files selected in Yazi before running restore/delete operations
- Use `Space` to select files or `v`/`V` for visual selection mode

## 💡 Recommendations

### Companion Plugin

For an even better trash management experience, pair this plugin with:

**[restore.yazi](https://github.com/boydaihungst/restore.yazi)** - Undo your delete history by your latest deleted files/folders

This companion plugin adds an "undo" feature that lets you press `u` to instantly restore the last deleted file. You can keep hitting `u` repeatedly to step through your entire delete history, making accidental deletions a thing of the past.

**Perfect combination:** Use `restore.yazi` for quick single-file undos and `recycle-bin.yazi` for comprehensive trash management and bulk operations.
