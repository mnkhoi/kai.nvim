local uv = vim.uv or vim.loop

local Log = {}

---@type integer
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
end

Log.log = function(level, msg, ...)
	if Log.level <= level then
		initialize()
		local text = format(level, msg, ...)
		write(text)
	end
end

return Log
