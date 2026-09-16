---Backend: owns the `pi --mode rpc` child process.
---Strict LF-delimited JSONL framing, id-correlated responses, event fan-out,
---and extension_ui_request routing.
local uv = vim.uv or vim.loop

local M = {}

local config = require("kai.config")
local logger = require("kai.logger")
local serialize = require("kai.rpc.serialize")
local ext_ui = require("kai.rpc.extension_ui")

---@class kai.pi.pending
---@field command string
---@field callback fun(resp: table)?

M.proc = nil ---@type {handle: userdata?, pid: number?}?
M.pipes = nil ---@type {stdin: userdata?, stdout: userdata?, stderr: userdata?}?
M.framer = nil
M.stderr_buf = ""

---@type table<string, kai.pi.pending>
M.pending = {}
M.req_counter = 0

---@type table<string, fun(payload: table)[]>
M.listeners = {}

---@type table state cache from get_state/agent events
M.state = {
	isStreaming = false,
	isCompacting = false,
	model = nil,
	thinkingLevel = nil,
	sessionId = nil,
	sessionFile = nil,
	sessionName = nil,
}

-- ── events ────────────────────────────────────────────────────────────────

---@param event string event type or "*" for all
---@param fn fun(payload: table)
---@return fun() unsubscribe
function M.on(event, fn)
	if not M.listeners[event] then
		M.listeners[event] = {}
	end
	M.listeners[event][#M.listeners[event] + 1] = fn
	return function()
		local list = M.listeners[event]
		if not list then
			return
		end
		for i, f in ipairs(list) do
			if f == fn then
				table.remove(list, i)
				break
			end
		end
	end
end

---@param event string
---@param payload table
function M.emit(event, payload)
	if type(payload) == "table" and payload.type == nil then
		payload.type = event
	end
	local function call(list)
		if not list then
			return
		end
		for _, fn in ipairs(vim.tbl_values(list)) do
			local ok, err = pcall(fn, payload)
			if not ok then
				logger.error("kai event handler error (%s): %s", event, tostring(err))
			end
		end
	end
	-- Specific listeners run in vim.schedule (uv thread safety for vim.api users).
	-- "*" receives every event exactly once.
	vim.schedule(function()
		if event == "*" then
			call(M.listeners["*"])
			return
		end
		call(M.listeners[event])
		call(M.listeners["*"])
	end)
end

---Emit to specific + generic response listeners without double-notifying "*".
---@param resp table
function M.emit_response(resp)
	vim.schedule(function()
		local function call(list)
			if not list then
				return
			end
			for _, fn in ipairs(vim.tbl_values(list)) do
				local ok, err = pcall(fn, resp)
				if not ok then
					logger.error("kai response handler error: %s", tostring(err))
				end
			end
		end
		call(M.listeners["response:" .. tostring(resp.command)])
		call(M.listeners["response"])
		call(M.listeners["*"])
	end)
end

-- ── lifecycle ─────────────────────────────────────────────────────────────

---@return boolean running
function M.is_running()
	return M.proc ~= nil and M.proc.handle ~= nil and not M.proc.handle:is_closing()
end

function M.next_id()
	M.req_counter = M.req_counter + 1
	return string.format("kai-%d-%d", (uv.now and uv.now() or 0), M.req_counter)
end

---Start the pi RPC process. Idempotent.
---@param opts {force?: boolean}? pass force=true to restart
---@return boolean ok
function M.start(opts)
	opts = opts or {}
	if M.is_running() then
		if not opts.force then
			return true
		end
		M.stop()
	end

	local cfg = config.options
	local cmd = cfg.pi_cmd or "pi"
	local args = config.build_pi_args()
	local cwd = config.resolve_cwd()

	M.pipes = {
		stdin = uv.new_pipe(false),
		stdout = uv.new_pipe(false),
		stderr = uv.new_pipe(false),
	}
	M.framer = serialize.new_framer()
	M.stderr_buf = ""

	local handle, pid
	local ok, err = pcall(function()
		handle, pid = uv.spawn(cmd, {
			args = args,
			cwd = cwd,
			stdio = { M.pipes.stdin, M.pipes.stdout, M.pipes.stderr },
			env = nil,
			uid = nil,
			gid = nil,
			verbatim = true,
			detached = false,
			hide = true,
		}, function(code, signal)
			vim.schedule(function()
				logger.info("pi exited code=%s signal=%s", tostring(code), tostring(signal))
				M.emit("pi_exit", { code = code, signal = signal })
				M.cleanup()
				if code ~= 0 and code ~= nil then
					vim.notify(
						string.format("[kai] pi exited (%s). Stderr tail:\n%s", tostring(code), M.stderr_tail()),
						vim.log.levels.ERROR
					)
				end
			end)
		end)
	end)
	if not ok or not handle then
		vim.notify("[kai] failed to spawn '" .. cmd .. "': " .. tostring(err or handle), vim.log.levels.ERROR)
		logger.error("spawn failed: %s %s", cmd, tostring(err))
		M.cleanup()
		return false
	end

	M.proc = { handle = handle, pid = pid }
	logger.info("spawned pi pid=%s cmd=%s args=%s cwd=%s", tostring(pid), cmd, vim.inspect(args), cwd)

	uv.read_start(M.pipes.stdout, function(read_err, data)
		if read_err then
			logger.error("stdout read error: %s", tostring(read_err))
			return
		end
		if data then
			M.on_stdout_chunk(data)
		else
			-- EOF
			logger.info("pi stdout EOF")
		end
	end)

	uv.read_start(M.pipes.stderr, function(read_err, data)
		if data then
			M.stderr_buf = (M.stderr_buf .. data):sub(-8192)
			logger.warn("pi stderr: %s", data:sub(1, 500))
		end
	end)

	M.emit("pi_start", { pid = pid, cwd = cwd })
	return true
end

function M.stderr_tail()
	local tail = M.stderr_buf or ""
	local lines = vim.split(tail, "\n", { plain = true })
	local n = #lines
	local from = math.max(1, n - 9)
	return table.concat(vim.list_slice(lines, from, n), "\n")
end

function M.cleanup()
	if M.pipes then
		for _, key in ipairs({ "stdin", "stdout", "stderr" }) do
			local p = M.pipes[key]
			if p and not p:is_closing() then
				pcall(function()
					if key == "stdin" then
						p:shutdown(function() end)
					end
				end)
				pcall(function()
					p:close()
				end)
			end
		end
	end
	M.pipes = nil
	M.proc = nil
	-- Fail all pending with process death.
	for id, pend in pairs(M.pending) do
		if pend.callback then
			vim.schedule(function()
				pcall(pend.callback, {
					type = "response",
					id = id,
					command = pend.command,
					success = false,
					error = "pi process exited",
				})
			end)
		end
	end
	M.pending = {}
	M.state.isStreaming = false
	M.state.isCompacting = false
end

---Stop the pi process.
function M.stop()
	if M.proc and M.proc.handle and not M.proc.handle:is_closing() then
		pcall(function()
			M.proc.handle:kill("SIGTERM")
		end)
		-- Give it a moment, then SIGKILL + cleanup via exit handler.
		local handle = M.proc.handle
		vim.defer_fn(function()
			if handle and not handle:is_closing() then
				pcall(function()
					handle:kill("SIGKILL")
				end)
			end
		end, 800)
	else
		M.cleanup()
	end
end

-- ── inbound ───────────────────────────────────────────────────────────────

---@param chunk string raw stdout bytes
function M.on_stdout_chunk(chunk)
	local lines = M.framer:feed(chunk)
	for _, line in ipairs(lines) do
		if line ~= "" then
			local data, kind = serialize.deserialize(line)
			if data then
				M.dispatch(data, kind)
			end
		end
	end
end

---@param data table
---@param kind string?
function M.dispatch(data, kind)
	if kind == "response" then
		M.on_response(data)
	elseif kind == "extension_ui_request" then
		---@cast data kai.ext_ui.request
		ext_ui.handle(data, function(resp)
			M.send_raw(resp, nil)
		end)
		M.emit("extension_ui_request", data)
	elseif kind == "events" then
		M.track_state(data)
		M.emit(data.type, data)
	else
		M.emit(data.type or "unknown", data)
	end
end

function M.track_state(ev)
	if ev.type == "agent_start" then
		M.state.isStreaming = true
	elseif ev.type == "agent_settled" then
		M.state.isStreaming = false
	elseif ev.type == "compaction_start" then
		M.state.isCompacting = true
	elseif ev.type == "compaction_end" then
		M.state.isCompacting = false
	elseif ev.type == "queue_update" then
		M.state.steering = ev.steering
		M.state.followUp = ev.followUp
	end
end

---@param resp table
function M.on_response(resp)
	local id = resp.id
	if id and M.pending[id] then
		local pend = M.pending[id]
		M.pending[id] = nil
		if pend.callback then
			vim.schedule(function()
				local ok, err = pcall(pend.callback, resp)
				if not ok then
					logger.error("response callback error: %s", tostring(err))
				end
			end)
		end
		-- Single fan-out: specific + generic + "*" exactly once.
		M.emit_response(resp)
	else
		-- Unsolicited (no id) or late response: still fan out once.
		M.emit_response(resp)
		if resp.success == false then
			logger.warn("RPC error [%s]: %s", tostring(resp.command), tostring(resp.error))
		end
	end
end

-- ── outbound ──────────────────────────────────────────────────────────────

---@param obj table command table (must include `type`)
---@param on_response fun(resp: table)? optional response callback
---@return string? id assigned
function M.send_raw(obj, on_response)
	if not M.is_running() then
		local started = M.start()
		if not started then
			if on_response then
				vim.schedule(function()
					on_response({ type = "response", command = obj.type, success = false, error = "not running" })
				end)
			end
			return nil
		end
	end
	if obj.id == nil and obj.type ~= "abort" and obj.type ~= "abort_bash" and obj.type ~= "abort_retry" then
		obj.id = M.next_id()
	end
	if obj.id and on_response then
		M.pending[obj.id] = { command = obj.type, callback = on_response }
	end
	local line = serialize.serialize(obj)
	if not line then
		if obj.id then
			M.pending[obj.id] = nil
		end
		return nil
	end
	local pipe = M.pipes and M.pipes.stdin
	if not pipe or pipe:is_closing() then
		if obj.id then
			M.pending[obj.id] = nil
		end
		logger.error("stdin pipe closed, cannot send %s", obj.type)
		return nil
	end
	pipe:write(line .. "\n", function(write_err)
		if write_err then
			logger.error("write failed (%s): %s", obj.type, tostring(write_err))
			if obj.id and M.pending[obj.id] then
				local pend = M.pending[obj.id]
				M.pending[obj.id] = nil
				if pend.callback then
					vim.schedule(function()
						pend.callback({
							type = "response",
							id = obj.id,
							command = obj.type,
							success = false,
							error = tostring(write_err),
						})
					end)
				end
			end
		end
	end)
	return obj.id
end

---@param obj table
---@param on_response fun(resp: table)?
function M.request(obj, on_response)
	return M.send_raw(obj, on_response)
end

-- ── convenience wrappers (all accept optional on_response callback) ───────

---@param message string
---@param opts {images?: table?, streamingBehavior?: string?, id?: string?}?
---@param on_response fun(resp:table)?
function M.prompt(message, opts, on_response)
	if type(opts) == "function" then
		on_response = opts
		opts = {}
	end
	opts = opts or {}
	-- Auto-steer when busy unless caller says otherwise (matches RPC rule that
	-- bare `prompt` errors while streaming).
	if M.state.isStreaming and not opts.streamingBehavior then
		opts.streamingBehavior = "steer"
	end
	return M.request({
		type = "prompt",
		message = message,
		images = opts.images,
		streamingBehavior = opts.streamingBehavior,
		id = opts.id,
	}, on_response)
end

function M.steer(message, opts, on_response)
	if type(opts) == "function" then
		on_response = opts
		opts = {}
	end
	opts = opts or {}
	return M.request({ type = "steer", message = message, images = opts.images }, on_response)
end

function M.follow_up(message, opts, on_response)
	if type(opts) == "function" then
		on_response = opts
		opts = {}
	end
	opts = opts or {}
	return M.request({ type = "follow_up", message = message, images = opts.images }, on_response)
end

function M.abort(on_response)
	return M.request({ type = "abort" }, on_response)
end

function M.clear_queue(on_response)
	return M.request({ type = "clear_queue" }, on_response)
end

function M.new_session(parentSession, on_response)
	if type(parentSession) == "function" then
		on_response = parentSession
		parentSession = nil
	end
	local req = { type = "new_session" }
	if parentSession then
		req.parentSession = parentSession
	end
	return M.request(req, on_response)
end

function M.get_state(on_response)
	return M.request({ type = "get_state" }, on_response)
end

function M.get_messages(on_response)
	return M.request({ type = "get_messages" }, on_response)
end

function M.get_commands(on_response)
	return M.request({ type = "get_commands" }, on_response)
end

function M.set_model(provider, modelId, on_response)
	return M.request({ type = "set_model", provider = provider, modelId = modelId }, on_response)
end

function M.cycle_model(on_response)
	return M.request({ type = "cycle_model" }, on_response)
end

function M.get_available_models(on_response)
	return M.request({ type = "get_available_models" }, on_response)
end

function M.set_thinking_level(level, on_response)
	return M.request({ type = "set_thinking_level", level = level }, on_response)
end

function M.cycle_thinking_level(on_response)
	return M.request({ type = "cycle_thinking_level" }, on_response)
end

function M.get_available_thinking_levels(on_response)
	return M.request({ type = "get_available_thinking_levels" }, on_response)
end

function M.set_steering_mode(mode, on_response)
	return M.request({ type = "set_steering_mode", mode = mode }, on_response)
end

function M.set_follow_up_mode(mode, on_response)
	return M.request({ type = "set_follow_up_mode", mode = mode }, on_response)
end

function M.compact(customInstructions, on_response)
	if type(customInstructions) == "function" then
		on_response = customInstructions
		customInstructions = nil
	end
	local req = { type = "compact" }
	if customInstructions then
		req.customInstructions = customInstructions
	end
	return M.request(req, on_response)
end

function M.set_auto_compaction(enabled, on_response)
	return M.request({ type = "set_auto_compaction", enabled = enabled }, on_response)
end

function M.set_auto_retry(enabled, on_response)
	return M.request({ type = "set_auto_retry", enabled = enabled }, on_response)
end

function M.abort_retry(on_response)
	return M.request({ type = "abort_retry" }, on_response)
end

function M.bash(command, on_response)
	return M.request({ type = "bash", command = command }, on_response)
end

function M.abort_bash(on_response)
	return M.request({ type = "abort_bash" }, on_response)
end

function M.get_session_stats(on_response)
	return M.request({ type = "get_session_stats" }, on_response)
end

function M.export_html(outputPath, on_response)
	if type(outputPath) == "function" then
		on_response = outputPath
		outputPath = nil
	end
	local req = { type = "export_html" }
	if outputPath then
		req.outputPath = outputPath
	end
	return M.request(req, on_response)
end

function M.switch_session(sessionPath, on_response)
	return M.request({ type = "switch_session", sessionPath = sessionPath }, on_response)
end

function M.fork(entryId, on_response)
	return M.request({ type = "fork", entryId = entryId }, on_response)
end

function M.clone(on_response)
	return M.request({ type = "clone" }, on_response)
end

function M.get_fork_messages(on_response)
	return M.request({ type = "get_fork_messages" }, on_response)
end

function M.get_entries(since, on_response)
	if type(since) == "function" then
		on_response = since
		since = nil
	end
	local req = { type = "get_entries" }
	if since then
		req.since = since
	end
	return M.request(req, on_response)
end

function M.get_tree(on_response)
	return M.request({ type = "get_tree" }, on_response)
end

function M.get_last_assistant_text(on_response)
	return M.request({ type = "get_last_assistant_text" }, on_response)
end

function M.set_session_name(name, on_response)
	return M.request({ type = "set_session_name", name = name }, on_response)
end

return M
