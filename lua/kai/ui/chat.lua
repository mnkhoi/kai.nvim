---Separate chat buffer + input buffer frontend for pi RPC.
---Layout (default, placement="right"):
---  +--------------+-----------+
---  | editor       | chat      |
---  |              |-----------|
---  |              | input (6) |
---  +--------------+-----------+
local logger = require("kai.logger")
local spinner = require("kai.ui.spinner")
local context = require("kai.ui.context")

local M = {}

M.chat_buf = nil ---@type integer?
M.chat_win = nil ---@type integer?
M.input_buf = nil ---@type integer?
M.input_win = nil ---@type integer?
M.prev_win = nil ---@type integer?

M.ns = vim.api.nvim_create_namespace("kai_chat")
M.stream = nil ---@type {text_by_idx: table<number,string>, thinking: string, line_start: integer}?
M.statuses = {} ---@type table<string,string>
M.widgets = {} ---@type table<string,string[]>
M.history = {} ---@type string[]
M.history_idx = 0
M.thinking_line = nil ---@type integer?
M.default_winbar = " kai · pi "

-- ── buffer helpers ────────────────────────────────────────────────────────

local function is_valid(buf)
	return buf ~= nil and vim.api.nvim_buf_is_valid(buf)
end

local function win_valid(win)
	return win ~= nil and vim.api.nvim_win_is_valid(win)
end

function M.is_open()
	return (win_valid(M.chat_win) and is_valid(M.chat_buf)) and true or false
end

local function unlock()
	if is_valid(M.chat_buf) then
		vim.api.nvim_buf_set_option(M.chat_buf, "modifiable", true)
	end
end

local function lock()
	if is_valid(M.chat_buf) then
		vim.api.nvim_buf_set_option(M.chat_buf, "modifiable", false)
	end
end

---@param lines string[]
function M.append_lines(lines)
	if not is_valid(M.chat_buf) then
		return
	end
	unlock()
	local count = vim.api.nvim_buf_line_count(M.chat_buf)
	-- Drop the single initial empty line convention.
	if count == 1 then
		local first = vim.api.nvim_buf_get_lines(M.chat_buf, 0, 1, false)[1]
		if first == "" then
			vim.api.nvim_buf_set_lines(M.chat_buf, 0, 1, false, lines)
			lock()
			M.follow_output()
			return
		end
	end
	vim.api.nvim_buf_set_lines(M.chat_buf, count, count, false, lines)
	lock()
	M.follow_output()
end

function M.follow_output()
	if win_valid(M.chat_win) and is_valid(M.chat_buf) then
		local count = vim.api.nvim_buf_line_count(M.chat_buf)
		pcall(vim.api.nvim_win_set_cursor, M.chat_win, { count, 0 })
	end
end

---@param line integer 1-indexed
---@param new_lines string[]
function M.replace_lines(line, end_line, new_lines)
	if not is_valid(M.chat_buf) then
		return
	end
	unlock()
	vim.api.nvim_buf_set_lines(M.chat_buf, line - 1, end_line - 1, false, new_lines)
	lock()
end

-- ── layout ────────────────────────────────────────────────────────────────

function M.open()
	if M.is_open() then
		if win_valid(M.input_win) then
			vim.api.nvim_set_current_win(M.input_win)
		end
		return
	end
	local cfg_ok, cfg = pcall(require, "kai.config")
	local wcfg = (cfg_ok and cfg.options.window) or { placement = "right", width = 80, input_height = 6 }

	M.prev_win = vim.api.nvim_get_current_win()

	-- Chat window
	if (wcfg.placement or "right") == "left" then
		vim.cmd("topleft vsplit")
	else
		vim.cmd("botright vsplit")
	end
	M.chat_win = vim.api.nvim_get_current_win()
	M.chat_buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_win_set_buf(M.chat_win, M.chat_buf)
	vim.api.nvim_win_set_width(M.chat_win, wcfg.width or 80)
	vim.api.nvim_buf_set_option(M.chat_buf, "buftype", "nofile")
	vim.api.nvim_buf_set_option(M.chat_buf, "bufhidden", "hide")
	vim.api.nvim_buf_set_option(M.chat_buf, "swapfile", false)
	vim.api.nvim_buf_set_option(M.chat_buf, "filetype", "markdown")
	vim.api.nvim_buf_set_option(M.chat_buf, "modifiable", false)
	vim.api.nvim_buf_set_option(M.chat_buf, "wrap", true)
	vim.api.nvim_buf_set_option(M.chat_buf, "linebreak", true)
	vim.api.nvim_buf_set_option(M.chat_buf, "cursorline", true)
	vim.api.nvim_win_set_option(M.chat_win, "number", false)
	vim.api.nvim_win_set_option(M.chat_win, "relativenumber", false)
	vim.api.nvim_win_set_option(M.chat_win, "wrap", true)
	vim.api.nvim_win_set_option(M.chat_win, "winfixwidth", true)
	pcall(vim.api.nvim_win_set_option, M.chat_win, "winbar", M.default_winbar)
	pcall(vim.api.nvim_buf_set_name, M.chat_buf, "kai://chat")

	-- Input window below chat
	vim.cmd("belowright split")
	M.input_win = vim.api.nvim_get_current_win()
	M.input_buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_win_set_buf(M.input_win, M.input_buf)
	vim.api.nvim_win_set_height(M.input_win, wcfg.input_height or 6)
	vim.api.nvim_buf_set_option(M.input_buf, "buftype", "nofile")
	vim.api.nvim_buf_set_option(M.input_buf, "bufhidden", "hide")
	vim.api.nvim_buf_set_option(M.input_buf, "swapfile", false)
	vim.api.nvim_buf_set_option(M.input_buf, "filetype", "markdown")
	vim.api.nvim_buf_set_option(M.input_buf, "wrap", true)
	vim.api.nvim_win_set_option(M.input_win, "number", false)
	vim.api.nvim_win_set_option(M.input_win, "relativenumber", false)
	vim.api.nvim_win_set_option(M.input_win, "winfixheight", true)
	pcall(vim.api.nvim_win_set_option, M.input_win, "winbar", " message · <CR> send · <C-c> clear ")
	pcall(vim.api.nvim_buf_set_name, M.input_buf, "kai://input")

	M.setup_keymaps()
	M.seed_welcome()
	context.refresh_chat_header(M.chat_buf)
	context.refresh_input_hint(M.input_buf)
	vim.api.nvim_set_current_win(M.input_win)
	vim.cmd("startinsert")
end

function M.close()
	spinner.stop(M.chat_win, M.default_winbar)
	if win_valid(M.input_win) then
		pcall(vim.api.nvim_win_close, M.input_win, true)
	end
	if win_valid(M.chat_win) then
		pcall(vim.api.nvim_win_close, M.chat_win, true)
	end
	M.chat_win = nil
	M.input_win = nil
	-- Keep buffers for history; drop streaming state.
	M.stream = nil
	if M.prev_win and vim.api.nvim_win_is_valid(M.prev_win) then
		pcall(vim.api.nvim_set_current_win, M.prev_win)
	end
end

function M.toggle()
	if M.is_open() then
		M.close()
	else
		M.open()
	end
end

function M.focus_input()
	if not M.is_open() then
		M.open()
		return
	end
	if win_valid(M.input_win) then
		vim.api.nvim_set_current_win(M.input_win)
		vim.cmd("startinsert")
	end
end

function M.seed_welcome()
	if not is_valid(M.chat_buf) then
		return
	end
	if vim.api.nvim_buf_line_count(M.chat_buf) > 1 then
		return
	end
	local first = vim.api.nvim_buf_get_lines(M.chat_buf, 0, 1, false)[1]
	if first ~= "" then
		return
	end
	M.append_lines({
		"# kai · pi",
		"",
		"Type a message below and press `<CR>` (normal mode) or `<C-s>` (insert mode).",
		"`/model`, `/thinking`, `/compact`, `/new` work via `prompt` (e.g. `/model`).",
		"",
		"---",
		"",
	})
end

-- ── input ─────────────────────────────────────────────────────────────────

function M.get_input_text()
	if not is_valid(M.input_buf) then
		return ""
	end
	local lines = vim.api.nvim_buf_get_lines(M.input_buf, 0, -1, false)
	-- Trim trailing blanks (keep intentional leading whitespace).
	while #lines > 0 and lines[#lines]:match("^%s*$") do
		table.remove(lines)
	end
	return table.concat(lines, "\n")
end

function M.clear_input()
	if is_valid(M.input_buf) then
		vim.api.nvim_buf_set_lines(M.input_buf, 0, -1, false, { "" })
		context.refresh_input_hint(M.input_buf)
	end
end

function M.set_editor_text(text)
	if not is_valid(M.input_buf) then
		return
	end
	vim.api.nvim_buf_set_lines(M.input_buf, 0, -1, false, vim.split(text or "", "\n", { plain = true }))
	if M.is_open() then
		M.focus_input()
	end
end

function M.send_input()
	local text = M.get_input_text():gsub("^%s+", ""):gsub("%s+$", "")
	if text == "" then
		return
	end
	M.history[#M.history + 1] = text
	M.history_idx = #M.history + 1
	M.clear_input()
	vim.cmd("stopinsert")
	M.submit(text)
end

---@param text string user message to send to pi
function M.submit(text)
	local pi_ok, pi = pcall(require, "kai.pi")
	if not pi_ok then
		M.append_lines({ "> ⚠️ backend unavailable", "" })
		return
	end
	if not M.is_open() then
		M.open()
	end
	M.append_user(text)
	pi.prompt(text, function(resp)
		if not resp.success then
			M.append_lines({ "", "> ⚠️ `" .. tostring(resp.error or "prompt rejected") .. "`", "" })
		end
	end)
end

function M.history_prev()
	if #M.history == 0 or not is_valid(M.input_buf) then
		return
	end
	M.history_idx = math.max(1, M.history_idx - 1)
	vim.api.nvim_buf_set_lines(M.input_buf, 0, -1, false, vim.split(M.history[M.history_idx] or "", "\n"))
end

function M.history_next()
	if #M.history == 0 or not is_valid(M.input_buf) then
		return
	end
	M.history_idx = math.min(#M.history + 1, M.history_idx + 1)
	local text = M.history[M.history_idx] or ""
	vim.api.nvim_buf_set_lines(M.input_buf, 0, -1, false, vim.split(text, "\n"))
end

function M.setup_keymaps()
	vim.keymap.set("n", "<CR>", function()
		M.send_input()
	end, { buffer = M.input_buf, desc = "kai: send message", silent = true })
	vim.keymap.set("i", "<C-s>", function()
		M.send_input()
	end, { buffer = M.input_buf, desc = "kai: send message", silent = true })
	vim.keymap.set({ "n", "i" }, "<C-c>", function()
		M.clear_input()
	end, { buffer = M.input_buf, desc = "kai: clear input", silent = true })
	vim.keymap.set({ "n", "i" }, "<C-p>", function()
		M.history_prev()
	end, { buffer = M.input_buf, desc = "kai: prev history", silent = true })
	vim.keymap.set({ "n", "i" }, "<C-n>", function()
		M.history_next()
	end, { buffer = M.input_buf, desc = "kai: next history", silent = true })
	vim.keymap.set("n", "q", function()
		M.close()
	end, { buffer = M.chat_buf, desc = "kai: close chat", silent = true })
	-- Abort streaming with <Esc><Esc> from input.
	vim.keymap.set({ "n", "i" }, "<Esc><Esc>", function()
		local pi_ok, pi = pcall(require, "kai.pi")
		if pi_ok and pi.state.isStreaming then
			pi.abort()
		end
	end, { buffer = M.input_buf, desc = "kai: abort streaming", silent = true })

	-- Keep context hint fresh.
	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "BufEnter" }, {
		buffer = M.input_buf,
		callback = function()
			context.refresh_input_hint(M.input_buf)
		end,
	})
end

-- ── rendering: users / system / tools ─────────────────────────────────────

---@param text string
function M.append_user(text)
	local lines = { "## 🧑 You", "" }
	for _, l in ipairs(vim.split(text, "\n", { plain = true })) do
		lines[#lines + 1] = l
	end
	lines[#lines + 1] = ""
	M.append_lines(lines)
end

---@param text string
---@param kind "info"|"warn"|"error"?
function M.append_notify(text, kind)
	local icon = kind == "error" and "❌" or kind == "warning" and "⚠️" or "🔔"
	M.append_lines({ string.format("> %s %s", icon, text), "" })
end

---@param text string
function M.append_system(text)
	M.append_lines({ "> " .. text, "" })
end

---@param toolName string
---@param args any
function M.append_tool_start(toolName, args)
	local summary = ""
	if type(args) == "table" then
		if args.command then
			summary = "`" .. tostring(args.command):sub(1, 160) .. "`"
		elseif args.path then
			summary = "`" .. tostring(args.path):sub(1, 160) .. "`"
		else
			summary = vim.inspect(args):sub(1, 160)
		end
	end
	M.append_lines({ string.format("### 🔧 `%s` %s", toolName, summary), "" })
end

---@param toolName string
---@param result any
---@param isError boolean
function M.append_tool_end(toolName, result, isError)
	local text = ""
	if type(result) == "table" then
		if result.content and type(result.content) == "table" then
			local parts = {}
			for _, c in ipairs(result.content) do
				if type(c) == "table" and c.text then
					parts[#parts + 1] = c.text
				end
			end
			text = table.concat(parts, "\n")
		else
			text = vim.inspect(result):sub(1, 2000)
		end
	else
		text = tostring(result or "")
	end
	local icon = isError and "❌" or "✅"
	local lines = vim.split(text, "\n", { plain = true })
	local shown = {}
	for i = 1, math.min(#lines, 12) do
		shown[#shown + 1] = "    " .. lines[i]
	end
	if #lines > 12 then
		shown[#shown + 1] = string.format("    … (%d more lines)", #lines - 12)
	end
	if #shown == 0 then
		shown = { "    (no output)" }
	end
	local out = { string.format("%s `%s` %s", icon, toolName, isError and "failed" or "done"), "" }
	for _, l in ipairs(shown) do
		out[#out + 1] = l
	end
	out[#out + 1] = ""
	M.append_lines(out)
end

-- ── streaming assembly ────────────────────────────────────────────────────

function M.start_assistant()
	if M.stream then
		M.end_assistant()
	end
	local start_line = 1
	if is_valid(M.chat_buf) then
		start_line = vim.api.nvim_buf_line_count(M.chat_buf) + 1
	end
	M.stream = { text_by_idx = {}, thinking = "", line_start = start_line }
	M.append_lines({ "## 🤖 pi", "" })
	if is_valid(M.chat_buf) then
		M.stream.line_start = vim.api.nvim_buf_line_count(M.chat_buf) + 1
		-- Placeholder line that deltas rewrite (keeps cursor/extmark stable).
		M.append_lines({ "" })
	end
	if win_valid(M.chat_win) then
		spinner.start(M.chat_win, function(frame)
			M.update_thinking_virt(frame)
		end)
	end
end

function M.update_thinking_virt(frame)
	if not M.stream or not is_valid(M.chat_buf) then
		return
	end
	if M.thinking_line and M.thinking_line > 0 then
		pcall(vim.api.nvim_buf_clear_namespace, M.chat_buf, M.ns, M.thinking_line - 1, M.thinking_line)
	end
end

---@param delta string
---@param contentIndex number
function M.append_text_delta(delta, contentIndex)
	if not M.stream then
		M.start_assistant()
	end
	---@cast M.stream -nil
	local prev = M.stream.text_by_idx[contentIndex] or ""
	M.stream.text_by_idx[contentIndex] = prev .. delta
	M.render_stream_text()
end

function M.render_stream_text()
	if not M.stream or not is_valid(M.chat_buf) then
		return
	end
	-- Concatenate indices in order.
	local idxs = {}
	for k in pairs(M.stream.text_by_idx) do
		idxs[#idxs + 1] = k
	end
	table.sort(idxs)
	local parts = {}
	for _, k in ipairs(idxs) do
		parts[#parts + 1] = M.stream.text_by_idx[k]
	end
	local full = table.concat(parts, "")
	local lines = vim.split(full, "\n", { plain = true })
	if #lines == 0 then
		lines = { "" }
	end
	-- Always keep one trailing empty line as section padding.
	lines[#lines + 1] = ""
	M.replace_lines(M.stream.line_start, vim.api.nvim_buf_line_count(M.chat_buf) + 1, lines)
	M.follow_output()
end

---@param delta string
function M.append_thinking_delta(delta)
	if not M.stream then
		M.start_assistant()
	end
	---@cast M.stream -nil
	M.stream.thinking = M.stream.thinking .. delta
	-- Show only the tail as virtual text so thinking doesn't flood the buffer.
	local tail = M.stream.thinking:gsub("\n", " "):sub(-120)
	if is_valid(M.chat_buf) and win_valid(M.chat_win) then
		local count = vim.api.nvim_buf_line_count(M.chat_buf)
		pcall(vim.api.nvim_buf_clear_namespace, M.chat_buf, M.ns, count - 1, count)
		pcall(vim.api.nvim_buf_set_extmark, M.chat_buf, M.ns, count - 1, 0, {
			virt_lines = { { { "💭 " .. tail, "Comment" } } },
			priority = 20,
		})
	end
end

---@param message table? authoritative message_end payload
function M.end_assistant(message)
	if win_valid(M.chat_win) then
		spinner.stop(M.chat_win, M.default_winbar)
	end
	if is_valid(M.chat_buf) then
		pcall(vim.api.nvim_buf_clear_namespace, M.chat_buf, M.ns, 0, -1)
		context.refresh_chat_header(M.chat_buf)
	end
	-- If the authoritative message has no streaming text (e.g. tool-only turn),
	-- render its content blocks now.
	if message and type(message) == "table" and message.content and not M.stream then
		M.render_assistant_message(message)
	elseif message and M.stream and vim.tbl_isempty(M.stream.text_by_idx) then
		M.render_assistant_message(message)
	end
	if is_valid(M.chat_buf) then
		M.append_lines({ "", "---", "" })
	end
	M.stream = nil
	-- Refresh token/cost stats after each settled turn.
	vim.schedule(function()
		local pi_ok, pi = pcall(require, "kai.pi")
		if pi_ok and pi.is_running() then
			pi.get_session_stats(function(resp)
				if resp.success and resp.data and is_valid(M.chat_buf) then
					context.show_stats(M.chat_buf, resp.data)
				end
			end)
		end
	end)
end

---@param message table AssistantMessage
function M.render_assistant_message(message)
	if type(message) ~= "table" or type(message.content) ~= "table" then
		return
	end
	local texts = {}
	local thoughts = {}
	local tools = {}
	for _, block in ipairs(message.content) do
		if type(block) == "table" then
			if block.type == "text" and block.text then
				texts[#texts + 1] = block.text
			elseif block.type == "thinking" and block.thinking then
				thoughts[#thoughts + 1] = block.thinking
			elseif block.type == "toolCall" then
				tools[#tools + 1] = block
			end
		end
	end
	if #texts > 0 and (not M.stream or vim.tbl_isempty(M.stream.text_by_idx)) then
		if not M.stream then
			M.append_lines({ "## 🤖 pi", "" })
		end
		local lines = {}
		for _, t in ipairs(texts) do
			for _, l in ipairs(vim.split(t, "\n", { plain = true })) do
				lines[#lines + 1] = l
			end
		end
		lines[#lines + 1] = ""
		M.append_lines(lines)
	end
	for _, th in ipairs(thoughts) do
		local one = th:gsub("\n", " "):sub(1, 200)
		M.append_lines({ "> 💭 " .. one, "" })
	end
	for _, tc in ipairs(tools) do
		M.append_lines({ string.format("### 🔧 `%s`", tostring(tc.name or tc.toolName or "?")), "" })
	end
	if message.stopReason == "error" or message.errorMessage then
		M.append_lines({ "> ❌ " .. tostring(message.errorMessage or "error"), "" })
	end
end

-- ── extension-ui sink ─────────────────────────────────────────────────────

function M.set_status(key, text)
	if not key then
		return
	end
	if text == nil or text == "" then
		M.statuses[key] = nil
	else
		M.statuses[key] = text
	end
	M.render_statusline()
end

function M.set_widget(key, lines, placement)
	if not key then
		return
	end
	if lines == nil then
		M.widgets[key] = nil
	else
		M.widgets[key] = lines
	end
	-- Surface widgets as collapsible chat lines (aboveEditor default).
	if lines and #lines > 0 and M.is_open() then
		M.append_lines({ "> 🧩 [" .. key .. "]", "" })
		local indented = {}
		for _, l in ipairs(lines) do
			indented[#indented + 1] = "> " .. l
		end
		indented[#indented + 1] = ""
		M.append_lines(indented)
	end
end

function M.set_title(title)
	M.default_winbar = " kai · " .. (title or "pi") .. " "
	if win_valid(M.chat_win) and not spinner.is_active() then
		pcall(vim.api.nvim_win_set_option, M.chat_win, "winbar", M.default_winbar)
	end
end

function M.render_statusline()
	if not win_valid(M.chat_win) or spinner.is_active() then
		return
	end
	local parts = {}
	for k, v in pairs(M.statuses) do
		parts[#parts + 1] = k .. ": " .. v
	end
	local extra = #parts > 0 and (" · " .. table.concat(parts, " | ")) or ""
	pcall(vim.api.nvim_win_set_option, M.chat_win, "winbar", M.default_winbar .. extra)
end

-- ── backend wiring ────────────────────────────────────────────────────────

---@param pi table kai.pi backend
function M.attach_backend(pi)
	-- Register extension-ui sink (notify/status/widget/title/prefill).
	local ext_ok, ext_ui = pcall(require, "kai.rpc.extension_ui")
	if ext_ok then
		ext_ui.set_ui_sink({
			append_notify = function(msg, kind)
				if M.is_open() then
					M.append_notify(msg, kind)
				end
			end,
			set_status = function(k, t)
				M.set_status(k, t)
			end,
			set_widget = function(k, l, p)
				M.set_widget(k, l, p)
			end,
			set_title = function(t)
				M.set_title(t)
			end,
			set_editor_text = function(t)
				M.set_editor_text(t)
			end,
		})
	end

	pi.on("agent_start", function()
		if not M.is_open() then
			return
		end
		M.start_assistant()
	end)

	pi.on("message_update", function(ev)
		if not M.is_open() then
			return
		end
		local e = ev.assistantMessageEvent
		if type(e) ~= "table" then
			return
		end
		if e.type == "text_delta" and e.delta then
			M.append_text_delta(e.delta, e.contentIndex or 0)
		elseif e.type == "thinking_delta" and e.delta then
			M.append_thinking_delta(e.delta)
		elseif e.type == "toolcall_start" then
			M.append_tool_start(tostring(e.toolName or "?"), { id = e.id })
		elseif e.type == "toolcall_end" and e.toolCall then
			-- toolcall_end carries the full call; execution result arrives via tool_execution_end.
			logger.debug("toolcall_end %s", vim.inspect(e.toolCall):sub(1, 200))
		end
	end)

	pi.on("tool_execution_start", function(ev)
		if M.is_open() then
			M.append_tool_start(tostring(ev.toolName or "?"), ev.args)
		end
	end)

	pi.on("tool_execution_end", function(ev)
		if M.is_open() then
			M.append_tool_end(tostring(ev.toolName or "?"), ev.result, ev.isError == true)
		end
	end)

	pi.on("bash_execution_update", function(ev)
		if M.is_open() and ev.delta and ev.delta ~= "" then
			-- Stream direct `bash` RPC output as code block lines (throttled by chunk).
			local lines = {}
			for _, l in ipairs(vim.split(ev.delta, "\n", { plain = true })) do
				if l ~= "" then
					lines[#lines + 1] = "    " .. l
				end
			end
			if #lines > 0 then
				M.append_lines(lines)
			end
		end
	end)

	pi.on("message_end", function(ev)
		if M.is_open() and ev.message and ev.message.role == "assistant" then
			-- Authoritative message; stream already rendered text, so only finalize
			-- when stream was empty (tool-only) — handled in end_assistant.
		end
	end)

	pi.on("agent_end", function(ev)
		if M.is_open() then
			local msgs = ev.messages or {}
			-- Find last assistant message for authoritative finalize.
			local last = nil
			for i = #msgs, 1, -1 do
				if type(msgs[i]) == "table" and msgs[i].role == "assistant" then
					last = msgs[i]
					break
				end
			end
			M.end_assistant(last)
		end
		if ev.willRetry then
			M.append_system("retrying…")
		end
	end)

	pi.on("agent_settled", function()
		if M.is_open() and M.stream then
			M.end_assistant(nil)
		end
	end)

	pi.on("compaction_start", function(ev)
		M.append_system("compacting (" .. tostring(ev.reason or "?") .. ")…")
	end)
	pi.on("compaction_end", function(ev)
		if ev.aborted then
			M.append_system("compaction aborted")
		elseif ev.result and ev.result.summary then
			M.append_system("compacted: " .. tostring(ev.result.summary):sub(1, 300))
		elseif ev.errorMessage then
			M.append_system("compaction failed: " .. tostring(ev.errorMessage):sub(1, 300))
		end
	end)

	pi.on("auto_retry_start", function(ev)
		M.append_system(string.format("retry %d/%d in %dms: %s", ev.attempt or 0, ev.maxAttempts or 0, ev.delayMs or 0, tostring(ev.errorMessage or ""):sub(1, 200)))
	end)

	pi.on("queue_update", function(ev)
		local n = #(ev.steering or {}) + #(ev.followUp or {})
		if n > 0 then
			M.render_statusline()
		end
	end)

	pi.on("extension_error", function(ev)
		M.append_system("extension error [" .. tostring(ev.event or "?") .. "]: " .. tostring(ev.error or "?"):sub(1, 300))
	end)

	pi.on("response", function(resp)
		if resp.success == false then
			logger.warn("RPC %s failed: %s", tostring(resp.command), tostring(resp.error))
			if M.is_open() and resp.command ~= "get_session_stats" and resp.command ~= "get_state" then
				-- Surface user-facing command errors inline (not for background polls).
				M.append_lines({ "> ⚠️ `" .. tostring(resp.command) .. "`: " .. tostring(resp.error or "?"), "" })
			end
		end
	end)

	pi.on("pi_exit", function(info)
		if M.stream then
			M.end_assistant(nil)
		end
		M.append_system("pi exited (" .. tostring(info.code) .. ")")
	end)
end

return M
