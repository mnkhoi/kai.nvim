local uv = vim.uv or vim.loop

local Log = {}

---@type integer
Log.level = vim.log.levels.WARN

---@return string filepath for kai log
function Log.get_logfile()
	local ok, stdpath = pcall(vim.fn.stdpath, "log")
	if not ok then
		stdpath = vim.fn.stdpath("cache")
	end
	assert(type(stdpath) == "string")
	return vim.fs.joinpath(stdpath, "kai.log")
end

local initialized = false
local function initialize()
	if initialized then
		return
	end
	initialized = true
	local filepath = Log.get_logfile()

	local stat = uv.fs_stat(filepath)
	if stat and stat.size and stat.size > 10 * 1024 * 1024 then
		local backup = filepath .. ".backup"
		pcall(uv.fs_unlink, backup)
		pcall(uv.fs_rename, filepath, backup)
	end

	local parent = vim.fs.dirname(filepath)
	if parent then
		pcall(vim.fn.mkdir, parent, "p")
	end
end

---@param level integer
---@return string
local function level_name(level)
	if level == vim.log.levels.DEBUG then
		return "DEBUG"
	elseif level == vim.log.levels.INFO then
		return "INFO"
	elseif level == vim.log.levels.WARN then
		return "WARN"
	elseif level == vim.log.levels.ERROR then
		return "ERROR"
	else
		return "TRACE"
	end
end

local function write_line(text)
	initialize()
	local filepath = Log.get_logfile()
	local fd = uv.fs_open(filepath, "a", 438) -- 0666
	if not fd then
		return
	end
	uv.fs_write(fd, text .. "\n")
	uv.fs_close(fd)
end

---@param level integer log level
---@param msg string format string
---@param ... any format args
function Log.log(level, msg, ...)
	if level < Log.level then
		return
	end
	local ok, text = pcall(string.format, msg, ...)
	if not ok then
		text = msg .. " | " .. vim.inspect({ ... })
	end
	local stamp = os.date("%Y-%m-%d %H:%M:%S")
	write_line(string.format("[%s] [%s] %s", stamp, level_name(level), text))
end

function Log.debug(msg, ...)
	Log.log(vim.log.levels.DEBUG, msg, ...)
end

function Log.info(msg, ...)
	Log.log(vim.log.levels.INFO, msg, ...)
end

function Log.warn(msg, ...)
	Log.log(vim.log.levels.WARN, msg, ...)
end

function Log.error(msg, ...)
	Log.log(vim.log.levels.ERROR, msg, ...)
end

return Log
