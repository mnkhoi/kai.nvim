---Small-context virtual text (p99-inspired): tiny dimmed chips showing what the
---model sees without cluttering the chat: current file/selection, cwd, model,
---tokens/cost. Rendered as extmark virtual text, never as real lines.
local M = {}

M.ns = vim.api.nvim_create_namespace("kai_context")
M.stats = nil ---@type pi.type.SessionStats?
M.model_label = nil ---@type string?
M.file_chip = nil ---@type string?

---@param buf integer chat buffer to annotate
function M.show_stats(buf, stats)
	if not buf or not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	M.stats = stats
	M.refresh_chat_header(buf)
end

---@param buf integer
function M.refresh_chat_header(buf)
	if not buf or not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	local cfg_ok, cfg = pcall(require, "kai.config")
	if cfg_ok and cfg.options and cfg.options.context and cfg.options.context.show_stats == false then
		return
	end
	pcall(vim.api.nvim_buf_clear_namespace, buf, M.ns, 0, 1)
	if not M.stats and not M.model_label then
		return
	end
	local parts = {}
	if M.model_label then
		parts[#parts + 1] = M.model_label
	end
	if M.stats then
		if M.stats.contextUsage and M.stats.contextUsage.percent then
			parts[#parts + 1] = string.format("ctx %.0f%%", M.stats.contextUsage.percent)
		end
		if M.stats.tokens and M.stats.tokens.total then
			parts[#parts + 1] = string.format("%.1fk tok", (M.stats.tokens.total or 0) / 1000)
		end
		if M.stats.cost then
			parts[#parts + 1] = string.format("$%.3f", M.stats.cost)
		end
	end
	if #parts == 0 then
		return
	end
	local text = "  " .. table.concat(parts, " · ")
	pcall(vim.api.nvim_buf_set_extmark, buf, M.ns, 0, 0, {
		virt_text = { { text, "Comment" } },
		virt_text_pos = "right_align",
		hl_mode = "combine",
		priority = 10,
	})
end

---@param model table? pi.type.Model
function M.set_model(model)
	if type(model) == "table" and model.id then
		M.model_label = tostring(model.id):sub(1, 40)
	else
		M.model_label = nil
	end
end

---Build a `@file +selection` chip for the current editor context.
---@return string chip e.g. "@lua/kai/pi.lua:10-24" or "@lua/kai/pi.lua" or ""
function M.current_file_chip()
	local name = vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf())
	if name == "" then
		return ""
	end
	local cwd = vim.fn.getcwd()
	local rel = name
	if cwd ~= "" and name:sub(1, #cwd) == cwd then
		rel = name:sub(#cwd + 2)
	end
	-- Visual selection range (if in visual mode or last visual marks set)
	local has_range = false
	local l1, l2 = 0, 0
	local mode = vim.fn.mode()
	if mode == "v" or mode == "V" or mode == "\22" then
		has_range = true
		l1 = vim.fn.line("v")
		l2 = vim.fn.line(".")
	elseif vim.fn.getpos("'<")[2] > 0 and vim.fn.getpos("'>")[2] > 0 then
		-- Only treat as selection if marks are in the current buffer and recent.
		-- Keep it conservative: show range only in visual mode to avoid stale chips.
		has_range = false
	end
	if has_range then
		if l1 > l2 then
			l1, l2 = l2, l1
		end
		-- Cap range display (p99-style: small context, not whole file).
		if l2 - l1 > 50 then
			return string.format("@%s:%d-%d (+%d lines, truncated)", rel, l1, l1 + 50, l2 - l1 - 50)
		end
		return string.format("@%s:%d-%d", rel, l1, l2)
	end
	return "@" .. rel
end

---@param input_buf integer input buffer to annotate (eol virtual text on first line)
function M.refresh_input_hint(input_buf)
	if not input_buf or not vim.api.nvim_buf_is_valid(input_buf) then
		return
	end
	local cfg_ok, cfg = pcall(require, "kai.config")
	if cfg_ok and cfg.options and cfg.options.context and cfg.options.context.enabled == false then
		return
	end
	pcall(vim.api.nvim_buf_clear_namespace, input_buf, M.ns, 0, 1)
	local chip = M.current_file_chip()
	-- Hide chip when focus is inside kai windows (chip describes editor context).
	local cur = vim.api.nvim_get_current_buf()
	if cur == input_buf then
		-- Still show; the chip refers to the last editor buffer, which is fine.
	end
	if chip == "" then
		return
	end
	-- Only show on empty first line so we never cover user text.
	local ok, first = pcall(vim.api.nvim_buf_get_lines, input_buf, 0, 1, false)
	if not ok or not first or (first[1] ~= nil and first[1] ~= "") then
		return
	end
	pcall(vim.api.nvim_buf_set_extmark, input_buf, M.ns, 0, 0, {
		virt_text = { { "ctx " .. chip, "Comment" } },
		virt_text_pos = "eol",
		hl_mode = "combine",
		priority = 10,
	})
end

return M
