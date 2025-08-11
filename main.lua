-- ~/.config/yazi/plugins/recycle-bin/main.lua
-- Trash management system for Yazi

--=========== Plugin Settings =================================================
local isDebugEnabled = trash
local M = {}
local PLUGIN_NAME = "recycle-bin"
local USER_ID = ya.uid()
local XDG_RUNTIME_DIR = os.getenv("XDG_RUNTIME_DIR") or ("/run/user/" .. USER_ID)

--=========== Paths ===========================================================
local HOME = os.getenv("HOME")

--=========== Plugin State ===========================================================
---@enum
local STATE_KEY = {
	CONFIG = "CONFIG",
	HAS_FZF = "HAS_FZF",
}

--================= Notify / Logger ===========================================
local TIMEOUTS = {
	error = 8,
	warn = 8,
	info = 3,
}
local Notify = {}
---@param level "info"|"warn"|"error"|nil
---@param s string
---@param ... any
function Notify._send(level, s, ...)
	debug(s, ...)
	local content = Notify._parseContent(s, ...)
	local entry = {
		title = PLUGIN_NAME,
		content = content,
		timeout = TIMEOUTS[level] or 3,
		level = level,
	}
	ya.notify(entry)
end

function Notify._parseContent(s, ...)
	local ok, content = pcall(string.format, s, ...)
	if not ok then
		content = s
	end
	content = tostring(content):gsub("[\r\n]+", " "):gsub("%s+$", "")
	return content
end

function Notify.error(...)
	ya.err(...)
	Notify._send("error", ...)
end
function Notify.warn(...)
	Notify._send("warn", ...)
end
function Notify.info(...)
	Notify._send("info", ...)
end
function debug(...)
	if isDebugEnabled then
		local msg = Notify._parseContent(...)
		ya.dbg(msg)
	end
end

--========= Run terminal commands =======================================================
---@param cmd string
---@param args? string[]
---@param input? string  -- optional stdin input (e.g., password)
---@param is_silent? boolean
---@return string|nil, Output|nil
local function run_command(cmd, args, input, is_silent)
	debug("Executing command: " .. cmd .. (args and #args > 0 and (" " .. table.concat(args, " ")) or ""))
	local msgPrefix = "Command: " .. cmd .. " - "
	local cmd_obj = Command(cmd)

	-- Add arguments
	if type(args) == "table" and #args > 0 then
		for _, arg in ipairs(args) do
			cmd_obj:arg(arg)
		end
	end

	-- Set stdin mode if input is provided
	if input then
		cmd_obj:stdin(Command.PIPED)
	else
		cmd_obj:stdin(Command.INHERIT)
	end

	-- Set other streams
	cmd_obj:stdout(Command.PIPED):stderr(Command.PIPED):env("XDG_RUNTIME_DIR", XDG_RUNTIME_DIR)

	local child, cmd_err = cmd_obj:spawn()
	if not child then
		if not is_silent then
			Notify.error(msgPrefix .. "Failed to start. Error: %s", tostring(cmd_err))
		end
		return cmd_err and tostring(cmd_err), nil
	end

	-- Send stdin input if available
	if input then
		local ok, err = child:write_all(input)
		if not ok then
			if not is_silent then
				Notify.error(msgPrefix .. "Failed to write, stdin: %s", tostring(err))
			end
			return err and tostring(err), nil
		end

		local flushed, flush_err = child:flush()
		if not flushed then
			if not is_silent then
				Notify.error(msgPrefix .. "Failed to flush, stdin: %s", tostring(flush_err))
			end
			return flush_err and tostring(flush_err), nil
		end
	end

	-- Read output
	local output, out_err = child:wait_with_output()
	if not output then
		if not is_silent then
			Notify.error(msgPrefix .. "Failed to get output, error: %s", tostring(out_err))
		end
		return out_err and tostring(out_err), nil
	end

	-- Log outputs
	if output.stdout ~= "" and not is_silent then
		debug(msgPrefix .. "stdout: %s", output.stdout)
	end
	if output.status and output.status.code ~= 0 and not is_silent then
		Notify.warn(msgPrefix .. "Error code `%s`, success: `%s`", output.status.code, tostring(output.status.success))
	end

	-- Handle child output error
	if output.stderr ~= "" then
		if not is_silent then
			debug(msgPrefix .. "stderr: %s", output.stderr)
		end
		-- Only treat stderr as error if command actually failed
		if output.status and not output.status.success then
			return output.stderr, output
		end
	end

	return nil, output
end

--========= Sync helpers =======================================================
local set_state = ya.sync(function(state, key, value)
	state[key] = value
end)

local get_state = ya.sync(function(state, key)
	return state[key]
end)

--=========== Utils =================================================
---Combines two lists
local function list_extend(a, b)
	local result = {}
	for _, v in ipairs(a) do
		table.insert(result, v)
	end
	for _, v in ipairs(b) do
		table.insert(result, v)
	end
	return result
end

---Filters a list to get unique values
local function unique(list)
	local seen, out = {}, {}
	for _, v in ipairs(list) do
		if not seen[v] then
			seen[v] = true
			out[#out + 1] = v
		end
	end
	return out
end

--- Deep merge two tables: overrides take precedence
---@param defaults table
---@param overrides table|nil
---@return table
local function deep_merge(defaults, overrides)
	if type(overrides) ~= "table" then
		return defaults
	end

	local result = {}

	for k, v in pairs(defaults) do
		if type(v) == "table" and type(overrides[k]) == "table" then
			result[k] = deep_merge(v, overrides[k])
		else
			result[k] = overrides[k] ~= nil and overrides[k] or v
		end
	end

	-- Include any keys in overrides not in defaults
	for k, v in pairs(overrides) do
		if result[k] == nil then
			result[k] = v
		end
	end

	return result
end

---Show an input box.
---@param title string
---@param is_password boolean?
---@param value string?
---@return string|nil
local function prompt(title, is_password, value)
	debug("Prompting user for `%s`, is password: `%s`", title, is_password)
	local input_value, input_event = ya.input({
		title = title,
		value = value or "",
		obscure = is_password or false,
		position = { "center", y = 3, w = 60 },
	})

	if input_event ~= 1 then
		return nil
	end

	return input_value
end

---Present a simple which‑key style selector and return the chosen item (Max: 36 options).
---@param title string
---@param items string[]
---@return string|nil
local function choose_which(title, items)
	local keys = "1234567890abcdefghijklmnopqrstuvwxyz"
	local candidates = {}
	for i, item in ipairs(items) do
		if i > #keys then
			break
		end
		candidates[#candidates + 1] = { on = keys:sub(i, i), desc = item }
	end

	local idx = ya.which({ title = title, cands = candidates })
	return idx and items[idx]
end

---@param title string
---@param items string[]
---@return string|nil
local function choose_with_fzf(title, items)
	local permit = ya.hide()
	local result = nil

	local items_str = table.concat(items, "\n")
	local args = {
		"--prompt",
		title .. "> ",
		"--height",
		"100%",
		"--layout",
		"reverse",
		"--border",
	}

	local cmd = Command("fzf")
	for _, arg in ipairs(args) do
		cmd:arg(arg)
	end

	local child, err = cmd:stdin(Command.PIPED):stdout(Command.PIPED):stderr(Command.PIPED):spawn()
	if not child then
		Notify.error("Failed to start `fzf`: %s", tostring(err))
		permit:drop()
		return nil
	end

	child:write_all(items_str)
	child:flush()

	local output, wait_err = child:wait_with_output()
	if not output then
		Notify.error("Cannot read `fzf` output: %s", tostring(wait_err))
	else
		if output.status.success and output.status.code ~= 130 and output.stdout ~= "" then
			result = output.stdout:match("^(.-)\n?$")
		elseif output.status.code ~= 130 then
			Notify.error("`fzf` exited with error code %s. Stderr: %s", output.status.code, output.stderr)
		end
	end

	permit:drop()
	return result
end

local choose

---Shows a filterable list for the user to choose from.
---@param title string
---@param items string[]
---@param config table|nil Optional config to avoid state retrieval
---@return string|nil
local function choose_filtered(title, items, config)
	local query = prompt(title .. " (filter)")
	if query == nil then
		return nil
	end

	local filtered_items = {}
	if query == "" then
		filtered_items = items
	else
		query = query:lower()
		for _, item in ipairs(items) do
			if item:lower():find(query, 1, true) then
				table.insert(filtered_items, item)
			end
		end
	end

	if #filtered_items == 0 then
		Notify.warn("No items match your filter.")
		return nil
	end

	-- After filtering, restart the choose decision matrix
	return choose(title, filtered_items, config)
end

---@param count integer
---@param max integer
---@param preferred "auto"|"fzf"
---@return "fzf"|"menu"|"filter"
local function get_picker(count, max, preferred)
	local has_fzf = get_state(STATE_KEY.HAS_FZF)
	if preferred == "fzf" then
		return has_fzf and "fzf" or "filter"
	else
		if count > max then
			return has_fzf and "fzf" or "filter"
		else
			return "menu"
		end
	end
end

---Present a prompt to choose from a picker
---@param title string
---@param items string[]
---@param config table|nil Optional config to avoid state retrieval
---@return string|nil
choose = function(title, items, config)
	config = config or get_state(STATE_KEY.CONFIG)
	local picker = config.ui.picker or "auto"
	local max = config.ui.menu_max or 15

	debug("Picker: %s, max: %d", picker, max)

	if #items == 0 then
		return nil
	elseif #items == 1 then
		return items[1]
	end

	local mode = get_picker(#items, max, picker)

	debug("Mode: %s", mode)

	if mode == "fzf" then
		return choose_with_fzf(title, items)
	elseif mode == "menu" then
		return choose_which(title, items)
	elseif mode == "filter" then
		return choose_filtered(title, items, config)
	end
end

--============== File helpers ====================================
---Check if a path exists and is a directory
---@param url Url
---@return boolean
local function is_dir(url)
	local cha, _ = fs.cha(url)
	return cha and cha.is_dir or false
end

---Check if a directory is empty (more efficient than reading all entries)
---@param url Url
---@return boolean
local function is_dir_empty(url)
	local files, _ = fs.read_dir(url, { limit = 1 })
	return type(files) == "table" and #files == 0
end

--=========== api actions =================================================

local function cmd_open_trash()
	local config = get_state(STATE_KEY.CONFIG)
	local trash_files_dir = config.trash_dir .. "files"

	-- Ensure the trash files directory exists
	local trash_files_url = Url(trash_files_dir)
	if not is_dir(trash_files_url) then
		Notify.error("Trash files directory does not exist: %s", trash_files_dir)
		return
	end

	-- Navigate to the trash files directory in Yazi
	ya.emit("cd", { trash_files_url })
	Notify.info("Opened trash directory: %s", trash_files_dir)
end

local function cmd_empty_trash()
	local config = get_state(STATE_KEY.CONFIG)
end

local function cmd_restore_selection(args)
	local config = get_state(STATE_KEY.CONFIG)
end

--=========== init requirements ================================================

---Verify all dependencies
local function check_dependencies()
	-- Check for trash-cli
	local trashcli_err, _ = run_command("trash-list", { "--version" }, nil, true)
	if trashcli_err then
		local path = os.getenv("PATH") or "(unset)"
		Notify.error("trashcli not found. Is it installed and in PATH? PATH=" .. path)
		return false
	end

	-- Check for fzf (optional dependency)
	local fzf_err, _ = run_command("fzf", { "--version" }, nil, true)
	set_state(STATE_KEY.HAS_FZF, not fzf_err)
	return true
end

---Verify trash dir exists
local function check_has_trash_directory()
	local config = get_state(STATE_KEY.CONFIG)
	local trash_dir = config.trash_dir
	local trash_url = Url(trash_dir)

	if not is_dir(trash_url) then
		Notify.error("Trash directory not found: %s. Please check your configuration.", trash_dir)
		return false
	end

	return true
end

---Initialize the plugin, verify all dependencies
local function init()
	local initialized = get_state("is_initialized")
	if not initialized then
		if not check_dependencies() then
			return false
		end
		if not check_has_trash_directory() then
			return false
		end
		initialized = true
		set_state("is_initialized", true)
	end
	return initialized
end

--=========== Plugin start =================================================
-- Default configuration
local default_config = {
	trash_dir = HOME .. "/.local/share/Trash/",
	ui = {
		menu_max = 15, -- can go up to 36
		picker = "auto",
	},
}

---Merges user‑provided configuration options into the defaults.
---@param user_config table|nil
local function set_plugin_config(user_config)
	local config = deep_merge(default_config, user_config or {})
	set_state(STATE_KEY.CONFIG, config)
end

---Setup
function M:setup(cfg)
	set_plugin_config(cfg)
end

---Entry
function M:entry(job)
	if not init() then
		return
	end

	local action = job.args[1]
	if action == "open" then
		cmd_open_trash()
	elseif action == "restore" then
		cmd_restore_selection()
	elseif action == "empty" then
		cmd_empty_trash()
	else
		Notify.error("Unknown action")
	end
end

return M
