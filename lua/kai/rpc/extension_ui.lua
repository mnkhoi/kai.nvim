---Extension UI sub-protocol for RPC mode.
---Dialog methods (select/confirm/input/editor) block the agent until we reply
---with `extension_ui_response`. Fire-and-forget methods (notify/setStatus/...)
---just surface in Neovim.
local logger = require("kai.logger")

local M = {}

---@class kai.ext_ui.request
---@field type "extension_ui_request"
---@field id string
---@field method string
---@field title string?
---@field options string[]?
---@field message string?
---@field placeholder string?
---@field prefill string?
---@field notifyType "info"|"warning"|"error"?
---@field statusKey string?
---@field statusText string?
---@field widgetKey string?
---@field widgetLines string[]?
---@field widgetPlacement string?
---@field text string?

-- Forwarded to chat UI when available (set by kai.ui.chat to avoid cycles).
---@type table<string, fun(...):any>?
M.ui_sink = nil

---@param sink table
function M.set_ui_sink(sink)
	M.ui_sink = sink
end

local function notify_level(t)
	if t == "error" then
		return vim.log.levels.ERROR
	elseif t == "warning" then
		return vim.log.levels.WARN
	else
		return vim.log.levels.INFO
	end
end

---Handle one extension_ui_request. Must call `respond` exactly once for dialogs,
---never for fire-and-forget.
---@param req kai.ext_ui.request
---@param respond fun(resp: table) send extension_ui_response (already includes type+id)
function M.handle(req, respond)
	vim.schedule(function()
		local method = req.method
		if method == "select" then
			M.handle_select(req, respond)
		elseif method == "confirm" then
			M.handle_confirm(req, respond)
		elseif method == "input" then
			M.handle_input(req, respond)
		elseif method == "editor" then
			M.handle_editor(req, respond)
		elseif method == "notify" then
			vim.notify("[pi] " .. (req.message or ""), notify_level(req.notifyType))
			if M.ui_sink and M.ui_sink.append_notify then
				M.ui_sink.append_notify(req.message or "", req.notifyType or "info")
			end
		elseif method == "setStatus" then
			if M.ui_sink and M.ui_sink.set_status then
				M.ui_sink.set_status(req.statusKey, req.statusText)
			end
		elseif method == "setWidget" then
			if M.ui_sink and M.ui_sink.set_widget then
				M.ui_sink.set_widget(req.widgetKey, req.widgetLines, req.widgetPlacement)
			end
		elseif method == "setTitle" then
			if M.ui_sink and M.ui_sink.set_title then
				M.ui_sink.set_title(req.title)
			end
		elseif method == "set_editor_text" then
			if M.ui_sink and M.ui_sink.set_editor_text then
				M.ui_sink.set_editor_text(req.text or "")
			else
				logger.info("set_editor_text (no chat open): %s", (req.text or ""):sub(1, 120))
			end
		else
			logger.warn("Unknown extension_ui method: %s", tostring(method))
		end
	end)
end

function M.handle_select(req, respond)
	local title = req.title or "Select"
	local options = req.options or {}
	if #options == 0 then
		respond({ type = "extension_ui_response", id = req.id, cancelled = true })
		return
	end
	vim.ui.select(options, { prompt = title }, function(choice)
		if choice == nil then
			respond({ type = "extension_ui_response", id = req.id, cancelled = true })
		else
			respond({ type = "extension_ui_response", id = req.id, value = choice })
		end
	end)
end

function M.handle_confirm(req, respond)
	local title = req.title or "Confirm"
	if req.message and req.message ~= "" then
		title = title .. ": " .. req.message
	end
	vim.ui.select({ "Yes", "No" }, { prompt = title }, function(choice)
		if choice == nil then
			respond({ type = "extension_ui_response", id = req.id, cancelled = true })
		else
			respond({ type = "extension_ui_response", id = req.id, confirmed = choice == "Yes" })
		end
	end)
end

function M.handle_input(req, respond)
	local title = req.title or "Input"
	if req.placeholder and req.placeholder ~= "" then
		title = title .. " (" .. req.placeholder .. ")"
	end
	vim.ui.input({ prompt = title .. ": " }, function(value)
		if value == nil then
			respond({ type = "extension_ui_response", id = req.id, cancelled = true })
		else
			respond({ type = "extension_ui_response", id = req.id, value = value })
		end
	end)
end

-- Multi-line editor: open a temp scratch buffer; <CR><CR> or :wqa submits, :q! cancels.
-- Falls back to vim.ui.input when UI sink is unavailable.
function M.handle_editor(req, respond)
	local prefill = req.prefill or ""
	local responded = false
	local function once(resp)
		if responded then
			return
		end
		responded = true
		respond(resp)
	end

	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
	vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
	vim.api.nvim_buf_set_option(buf, "swapfile", false)
	vim.api.nvim_buf_set_option(buf, "filetype", "markdown")
	local lines = vim.split(prefill, "\n", { plain = true })
	if #lines == 0 then
		lines = { "" }
	end
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

	local width = math.floor(vim.o.columns * 0.6)
	local height = math.min(20, math.max(8, #lines + 4))
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = math.floor((vim.o.lines - height) / 2),
		col = math.floor((vim.o.columns - width) / 2),
		style = "minimal",
		border = "rounded",
		title = " " .. (req.title or "Edit text") .. " ",
		title_pos = "center",
	})
	vim.api.nvim_win_set_option(win, "wrap", true)
	vim.notify("[kai] Submit editor with <leader><CR>, cancel with <Esc><Esc> or :q!", vim.log.levels.INFO)

	local pclose ---@type fun() forward declaration (used by keymap below)
	pclose = function()
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
		if vim.api.nvim_buf_is_valid(buf) then
			vim.api.nvim_buf_delete(buf, { force = true })
		end
		once({ type = "extension_ui_response", id = req.id, cancelled = true })
	end

	vim.keymap.set({ "n", "i" }, "<Esc><Esc>", function()
		pclose()
	end, { buffer = buf, desc = "kai: cancel editor dialog" })

	local function submit()
		local content = {}
		if vim.api.nvim_buf_is_valid(buf) then
			content = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
		end
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
		if vim.api.nvim_buf_is_valid(buf) then
			vim.api.nvim_buf_delete(buf, { force = true })
		end
		once({ type = "extension_ui_response", id = req.id, value = table.concat(content, "\n") })
	end

	vim.keymap.set("n", "<leader><CR>", submit, { buffer = buf, desc = "kai: submit editor dialog" })
	vim.api.nvim_create_autocmd({ "WinClosed", "BufWipeout" }, {
		buffer = buf,
		once = true,
		callback = function()
			once({ type = "extension_ui_response", id = req.id, cancelled = true })
		end,
	})
end

return M
