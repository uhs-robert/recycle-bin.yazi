-- ~/.config/yazi/plugins/recycle-bin/main.lua
-- Trash management system for Yazi

--=========== Plugin Settings =================================================
local isDebugEnabled = false
local M = {}
local PLUGIN_NAME = "recycle-bin"
local USER_ID = ya.uid()
local XDG_RUNTIME_DIR = os.getenv("XDG_RUNTIME_DIR") or ("/run/user/" .. USER_ID)

--=========== Paths ===========================================================
local HOME = os.getenv("HOME")

--=========== Compiled Patterns (Performance Optimization) ==================
-- Pre-compiled string patterns for better performance
local PATTERNS = {
	filename = "([^/]+)$",
	trash_list = "^(%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d) (.+)$",
	line_break = "[^\n]+",
	line_break_crlf = "[^\r\n]+",
	size_info = "^(%S+)",
	whitespace_cleanup = "[\r\n]+",
	trailing_space = "%s+$",
	first_word = "%l",
	upper_first = "^%l",
}

--=========== Plugin State ===========================================================
---@enum
local STATE_KEY = {
	CONFIG = "CONFIG",
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
	content = tostring(content):gsub(PATTERNS.whitespace_cleanup, " "):gsub(PATTERNS.trailing_space, "")
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

---Create standardized ui.Text with common styling
---@param lines string|string[] Single line or array of lines
---@return table ui.Text object with standard alignment and wrapping
local function create_ui_list(lines)
	local line_objects = {}
	if type(lines) == "string" then
		table.insert(line_objects, ui.Line(lines))
	else
		for _, line in ipairs(lines) do
			table.insert(line_objects, ui.Line(line))
		end
	end
	return ui.Text(line_objects):align(ui.Align.LEFT):wrap(ui.Wrap.YES)
end

---Show a confirmation box.
---@param title string|table Confirmation title (string or structured ui.Line)
---@param body string|string[]|table? Confirmation body (string, string array, or structured ui.Text)
---@return boolean
local function confirm(title, body)
	local title_str = type(title) == "string" and title or tostring(title)
	debug("Confirming user action for `%s`", title_str)

	local confirmation_data = {
		title = type(title) == "string" and ui.Line(title) or title,
		pos = { "center", w = 60, h = 10 },
	}

	if body then
		-- Handle different body types
		if type(body) == "string" then
			confirmation_data.content = create_ui_list(body)
			confirmation_data.body = create_ui_list(body)
		elseif type(body) == "table" and body[1] and type(body[1]) == "string" then
			-- Array of strings
			confirmation_data.content = create_ui_list(body)
			confirmation_data.body = create_ui_list(body)
		else
			-- Structured UI component (ui.Text)
			confirmation_data.content = body
			confirmation_data.body = body
		end
	end

	local answer = ya.confirm(confirmation_data)
	return answer
end

--============== File helpers ====================================
---Check if a path exists and is a directory
---@param url Url
---@return boolean
local function is_dir(url)
	local cha, _ = fs.cha(url)
	return cha and cha.is_dir or false
end

--=========== Trash helpers =================================================
---Verify trash dir exists
---@param config table | nil
local function check_has_trash_directory(config)
	-- Get Config
	if not config then
		config = get_state(STATE_KEY.CONFIG)
	end
	-- Verify trash dir
	local trash_dir = config.trash_dir
	local trash_url = Url(trash_dir)

	if not is_dir(trash_url) then
		Notify.error("Trash directory not found: %s. Please check your configuration.", trash_dir)
		return false
	end

	return true
end

---Get count of items in trash
---@return integer, string|nil -- count, error
local function get_trash_item_count()
	local err, output = run_command("trash-list", {})
	if err then
		return 0, err
	end

	local item_count = 0
	if output and output.stdout ~= "" then
		_, item_count = output.stdout:gsub(PATTERNS.line_break, "")
	end

	return item_count, nil
end

---Get size of trash files directory
---@param config table
---@return string, string|nil -- size_string, error
local function get_trash_size(config)
	local trash_files_dir = config.trash_dir .. "files"

	local err, output = run_command("du", { "-sh", trash_files_dir }, nil, true)
	if err or not output or output.stdout == "" then
		return "unknown size", err
	end

	local size_info = output.stdout:match(PATTERNS.size_info)
	return size_info or "unknown size", nil
end

---Get size of trash files directory
---@param config table
---@return {count: integer, size: string}|table, {type: string, msg: string}|nil
local function get_trash_data(config)
	-- Default values
	local count = 0
	local size = "0M"

	-- Get trash info
	local item_count, count_err = get_trash_item_count()
	if count_err then
		return { count, size }, { type = "error", msg = string.format("Failed to get trash contents: %s", count_err) }
	end

	if item_count == 0 then
		return { count, size }, { type = "info", msg = "Trash is already empty" }
	end

	local size_info, size_err = get_trash_size(config)
	if size_err then
		debug("Failed to get trash size: %s", size_err)
	end

	return {
		count = item_count,
		size = size_info,
	}, nil
end

--=========== File Selection =================================================
---Get selected files from Yazi (based on archivemount.yazi pattern)
---@return string[]
local get_selected_files = ya.sync(function()
	local tab, paths = cx.active, {}
	for _, u in pairs(tab.selected) do
		paths[#paths + 1] = tostring(u)
	end
	if #paths == 0 and tab.current.hovered then
		paths[1] = tostring(tab.current.hovered.url)
	end
	return paths
end)

---Validates file selection and extracts filenames
---@param operation_name string The name of the operation (for logging/notifications)
---@return string[]|nil, string[]|nil -- selected_paths, item_names (or nil if validation fails)
local function validate_and_get_selection(operation_name)
	-- Get selected files from Yazi
	local selected_paths = get_selected_files()
	if #selected_paths == 0 then
		Notify.warn("No files selected for " .. operation_name)
		return nil, nil
	end

	debug("Selected paths for %s: %s", operation_name, table.concat(selected_paths, ", "))

	-- Extract filenames for confirmation dialog
	local item_names = {}
	for i, path in ipairs(selected_paths) do
		local filename = path:match(PATTERNS.filename) or path
		item_names[i] = filename
	end

	return selected_paths, item_names
end

--=========== Batch Operations =================================================
---Shows standardized confirmation dialog for batch operations
---@param verb string Action verb (e.g., "delete", "restore")
---@param items string[] List of item names
---@param warning string|nil Optional warning message
---@return boolean
local function confirm_batch_operation(verb, items, warning)
	local title = string.format("%s the following %d file(s):", verb:gsub(PATTERNS.upper_first, string.upper), #items)

	-- Create structured UI components for proper alignment and styling
	local body_components = {}

	-- Add each item as a formatted line with proper left alignment
	for _, item in ipairs(items) do
		table.insert(body_components, ui.Line({ ui.Span("  "), ui.Span(item) }):align(ui.Align.LEFT))
	end

	-- Add warning if provided with styling
	if warning then
		table.insert(body_components, ui.Line(""))
		table.insert(body_components, ui.Line(warning):style(th.notify.title_warn))
	end

	local structured_body = ui.Text(body_components):align(ui.Align.LEFT):wrap(ui.Wrap.YES)
	local confirmation = confirm(title, structured_body)
	if not confirmation then
		Notify.info(verb:gsub(PATTERNS.upper_first, string.upper) .. " cancelled")
		return false
	end

	return true
end

---Executes batch operation with progress tracking and error handling
---@param items table[] Array of items to process
---@param operation_name string Name of operation for notifications
---@param operation_func function Function that takes an item and returns error_string|nil
---@return integer, integer -- success_count, failed_count
local function execute_batch_operation(items, operation_name, operation_func)
	Notify.info(operation_name:gsub(PATTERNS.upper_first, string.upper) .. " %d file(s)...", #items)

	local success_count = 0
	local failed_count = 0

	for _, item in ipairs(items) do
		local err = operation_func(item)
		if err then
			failed_count = failed_count + 1
		else
			success_count = success_count + 1
		end
	end

	return success_count, failed_count
end

---Reports standardized operation results
---@param operation_name string Name of the operation
---@param success_count integer Number of successful operations
---@param failed_count integer Number of failed operations
local function report_operation_results(operation_name, success_count, failed_count)
	local past_tense = operation_name == "deleting" and "deleted"
		or operation_name == "restoring" and "restored"
		or operation_name .. "d"

	if success_count > 0 and failed_count == 0 then
		Notify.info("Successfully %s %d file(s)", past_tense, success_count)
	elseif success_count > 0 and failed_count > 0 then
		Notify.warn(
			"%s %d file(s), failed %d",
			past_tense:gsub(PATTERNS.upper_first, string.upper),
			success_count,
			failed_count
		)
	else
		Notify.error("Failed to %s any files", operation_name:gsub("ing$", ""))
	end
end

--=========== api actions =================================================
local function cmd_open_trash(config)
	local trash_files_dir = config.trash_dir .. "files"

	-- Ensure the trash files directory exists
	local trash_files_url = Url(trash_files_dir)
	if not is_dir(trash_files_url) then
		Notify.error("Trash files directory not found: %s", trash_files_dir)
		return
	end

	-- Navigate to the trash files directory in Yazi
	ya.emit("cd", { trash_files_url })
end

local function cmd_empty_trash(config)
	-- Check if trash directory exists
	if not check_has_trash_directory(config) then
		return
	end

	-- Get trash data
	local data, data_err = get_trash_data(config)
	if data_err then
		Notify[data_err.type](data_err.msg)
		return
	end

	-- Show confirmation dialog with details
	local body = string.format("Are you sure you want to delete these %d items (%s)?", data.count, data.size)
	local confirmation = confirm("Empty Trash", body)
	if not confirmation then
		Notify.info("Empty trash cancelled")
		return
	end

	-- Execute trash-empty command
	local err, _ = run_command("trash-empty", {}, "y\n")
	if err then
		Notify.error("Failed to empty trash: %s", err)
		return
	end
	Notify.info("Trash emptied successfully (%d items, %s freed)", data.count, data.size)
end

local function cmd_empty_trash_by_days(config)
	-- Check if trash directory exists
	if not check_has_trash_directory(config) then
		return
	end

	-- Get trash data prior to the operation to calculate difference
	local begin_data, begin_err = get_trash_data(config)
	if begin_err then
		Notify[begin_err.type](begin_err.msg)
		return
	end

	-- Prompt user for number of days
	local days_input = prompt("Delete trash items older than (days)", false, "30")
	if not days_input then
		Notify.info("Empty trash by days cancelled")
		return
	end

	-- Validate input is a positive integer
	local days = tonumber(days_input)
	if not days or days <= 0 or math.floor(days) ~= days then
		Notify.error("Invalid input: please enter a positive integer for days")
		return
	end

	-- Show confirmation dialog
	local body = string.format("Are you sure you want to delete all trash items older than %d days?", days)
	local confirmation = confirm("Empty Trash by Days", body)
	if not confirmation then
		Notify.info("Empty trash by days cancelled")
		return
	end

	-- Execute trash-empty command with days parameter
	Notify.info("Removing trash items older than %d days...", days)
	local err, _ = run_command("trash-empty", { tostring(days) }, "y\n")
	if err then
		Notify.error("Failed to empty trash by days: %s", err)
		return
	end

	-- Get trash data after the operation to calculate difference
	local end_data, end_err = get_trash_data(config)
	if end_err then
		Notify[end_err.type](end_err.msg)
		return
	end

	-- Calculate items deleted
	local items_deleted = begin_data.count - end_data.count

	Notify.info("Successfully removed %d trash items older than %d days", items_deleted, days)
end

local function cmd_delete_selection()
	-- Validate selection and get filenames
	local selected_paths, item_names = validate_and_get_selection("deletion")
	if not selected_paths or not item_names then
		return
	end

	-- Confirm deletion from trash with warning
	if not confirm_batch_operation("permanently delete", item_names, "This action cannot be undone!") then
		return
	end

	-- Create operation function for delete
	local function delete_operation(path)
		local filename = path:match(PATTERNS.filename) or path

		-- Use trash-rm with the filename as pattern
		-- trash-rm uses fnmatch patterns, so we pass the filename directly
		local delete_err, _ = run_command("trash-rm", { filename })
		if delete_err then
			Notify.error("Failed to delete %s: %s", filename, delete_err)
			return delete_err
		else
			debug("Successfully deleted from trash: %s", filename)
			return nil
		end
	end

	-- Execute batch operation
	local success_count, failed_count =
		execute_batch_operation(selected_paths, "permanently deleting", delete_operation)

	-- Report results
	report_operation_results("deleting", success_count, failed_count)
end

local function cmd_restore_selection()
	-- Validate selection and get filenames
	local selected_paths, _ = validate_and_get_selection("restoration")
	if not selected_paths then
		return
	end

	-- Build lookup table for O(1) filename matching
	local selected_lookup = {}
	for _, path in ipairs(selected_paths) do
		local filename = path:match(PATTERNS.filename) or path
		selected_lookup[filename] = true
	end

	-- Get trash list to find original paths
	local list_err, list_output = run_command("trash-list", {})
	if list_err or not list_output then
		Notify.error("Failed to get trash list: %s", list_err)
		return
	end

	-- Parse trash-list output and match with selected filenames
	-- Use single table to store related data for better memory efficiency
	local restore_items = {}
	local restore_count = 0

	debug(list_output)
	debug(list_output.stdout)

	for line in list_output.stdout:gmatch(PATTERNS.line_break_crlf) do
		-- Parse format: "YYYY-MM-DD HH:MM:SS /full/path/to/file"
		local datetime, original_path = line:match(PATTERNS.trash_list)
		if datetime and original_path then
			local filename = original_path:match(PATTERNS.filename) or original_path

			-- O(1) lookup
			if selected_lookup[filename] then
				restore_count = restore_count + 1
				restore_items[restore_count] = {
					path = original_path,
					name = filename,
				}
			end
		end
	end

	if restore_count == 0 then
		Notify.warn("No matching files found in trash")
		return
	end

	-- Build item names for confirmation dialog using more efficient method
	local restore_item_names = {}
	for i = 1, restore_count do
		restore_item_names[i] = restore_items[i].name
	end

	-- Confirm restoration
	if not confirm_batch_operation("restore", restore_item_names, nil) then
		return
	end

	-- Create operation function for restore
	local function restore_operation(item)
		-- Use trash-restore with the original path
		local restore_err, _ = run_command("trash-restore", { item.path }, "0\n")
		if restore_err then
			Notify.error("Failed to restore %s: %s", item.name, restore_err)
			return restore_err
		else
			debug("Successfully restored: %s", item.name)
			return nil
		end
	end

	-- Execute batch operation
	local success_count, failed_count = execute_batch_operation(restore_items, "restoring", restore_operation)

	-- Report results
	report_operation_results("restoring", success_count, failed_count)
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
	return true
end

---Initialize the plugin, verify all dependencies
local function init()
	local initialized = get_state("is_initialized")
	if not initialized then
		if not check_dependencies() then
			return false
		end
		local config = get_state(STATE_KEY.CONFIG)
		if not check_has_trash_directory(config) then
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

	-- Cache config to avoid multiple state access calls
	local config = get_state(STATE_KEY.CONFIG)
	local action = job.args[1]

	-- Pass config to functions that need it to avoid additional state calls
	if action == "open" then
		cmd_open_trash(config)
	elseif action == "delete" then
		cmd_delete_selection()
	elseif action == "restore" then
		cmd_restore_selection()
	elseif action == "emptyDays" then
		cmd_empty_trash_by_days(config)
	elseif action == "empty" then
		cmd_empty_trash(config)
	else
		Notify.error("Unknown action")
	end
end

return M
