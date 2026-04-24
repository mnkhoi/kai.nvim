local M = {}

local uv = vim.uv or vim.loop
local git = require("kai.git")
local rpc = require("kai.rpc.serialize")
local logger = require("kai.logger")

local exit_handler = function(code, signal)
	print("exit code", code)
	print("exit signal", signal)
end

---@param err string? error code
---@param data string? data that is received from pi
local read_handler = function(err, data)
	if err then
		logger.error(err)
		return
	elseif not data then
		--- End of file reached
		return
	end

	local msg_data, msg_type = rpc.deserialize(data)
end

local initialized = false
M.start = function()
	if initialized then
		return
	end
	initialized = true

	M.pipes = {
		stdin = uv.new_pipe(),
		stdout = uv.new_pipe(),
		stderr = uv.new_pipe(),
	}

	local curr_path = vim.fn.expand("%:p:h")

	local handle, pid = uv.spawn(git.get_root(curr_path) or curr_path, {
		args = {},
		stdio = { M.pipes.stdin, M.pipes.stdout, M.pipes.stderr },
		env = {},
		cwd = git.get_root(curr_path) or curr_path,
		hide = false,
		detached = false,
		uid = "",
		gid = "",
		verbatim = false,
	}, exit_handler)

	M.proc = {
		handle = handle,
		pid = pid,
	}

	local success, err, err_name = uv.read_start(M.pipes.stdout, read_handler)
end

return M
