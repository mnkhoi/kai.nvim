local uv = vim.uv or vim.loop

local levels_reverse = {}
for k, v in pairs(vim.log.levels) do
	levels_reverse[v] = k
end

local Log = {}

---@type vim.log.levels
Log.level = vim.log.levels.WARN

---@return string filepath for kai log
Log.get_logfile = function()
	local ok, stdpath = pcall(vim.fn.stdpath, "log")
	if not ok then
		stdpath = vim.fn.stdpath("cache")
	end

	assert(type(stdpath) == "string")
	return vim.fs.joinpath(stdpath, "kai.log")
end

---@param level integer log level
---@param msg string debug formatting string
---@param ... any[] anything you want to debug
local function format(level, msg, ...)
	local args = vim.F.pack_len(...)
	for i = 1, args.n do
		local v = args[i]
		if type(v) == "table" then
			args[i] = vim.inspect(v)
		elseif v == nil then
			args[i]("nil")
		end
	end

	local ok, text = pcall(string.format, msg, vim.F.unpack_len(args))

	local timestr = ""
	if ok then
		local str_level = levels_reverse[level]
		return string.format("%s[%s] %s", timestr, str_level, text)
	else
		return string.format(
			"%s[ERROR] error formating log line: '%s' args %s",
			timestr,
			vim.inspect(msg),
			vim.inspect(args)
		)
	end
end

---@param line string
local function write(line)
	--- Dynamically added during initialization
end

local initialized
local function initialize()
	if initialized then
		return
	end

	initialized = true
	local filepath = Log.get_logfile()

	local stat = uv.fs_stat(filepath)
	if stat and stat.size > 10 * 1024 * 1024 then
		local backup = filepath .. ".backup"
		uv.fs_unlink(backup)
		uv.fs_rename(filepath, backup)
	end

	local parent = vim.fs.dirname(filepath)
	require("kai.fs").mkdirp(parent)

	local logfile, openerr = io.open(filepath, "a+")
	if not logfile then
		local err_msg = string.format("Failed to open kai.nvim log file: %s", openerr)
		vim.notify(err_msg, vim.log.levels.ERROR)
	else
		write = function(line)
			logfile:write(line)
			logfile:write("\n")
			logfile:flush()
		end
	end
end

---@param level vim.log.levels print anything >= level
Log.set_log_level = function(level)
	Log.level = level
end

---@param level integer vim logger level
---@param msg string format message
---@param ... any[] item to view
Log.log = function(level, msg, ...)
	if Log.level <= level then
		initialize()
		local text = format(level, msg, ...)
		write(text)
	end
end

Log.warn = function(msg, ...)
	Log.log(vim.log.levels.WARN, msg, ...)
end

Log.error = function(msg, ...)
	Log.log(vim.log.levels.ERROR, msg, ...)
end

Log.debug = function(msg, ...)
	Log.log(vim.log.levels.DEBUG, msg, ...)
end

Log.info = function(msg, ...)
	Log.log(vim.log.levels.INFO, msg, ...)
end

Log.trace = function(msg, ...)
	Log.log(vim.log.levels.TRACE, msg, ...)
end
return Log
