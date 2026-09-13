local kai = {}

local attached = false

local function ensure_attached()
	if attached then
		return
	end
	attached = true
	local pi_ok, pi = pcall(require, "kai.pi")
	local chat_ok, chat = pcall(require, "kai.ui.chat")
	if pi_ok and chat_ok then
		chat.attach_backend(pi)
	end
end

---@param opts kai.opts?
function kai.setup(opts)
	local config = require("kai.config")
	config.setup(opts or {})
	require("kai.logger").level = config.options.log_level or vim.log.levels.WARN
	ensure_attached()
	kai.create_commands()
	return config.options
end

function kai.create_commands()
	local function cmd(name, fn, desc, nargs)
		pcall(vim.api.nvim_del_user_command, name)
		vim.api.nvim_create_user_command(name, fn, {
			desc = desc,
			nargs = nargs or 0,
			range = true,
		})
	end

	cmd("KaiToggle", function()
		kai.toggle()
	end, "kai: toggle chat window")

	cmd("KaiOpen", function()
		kai.open()
	end, "kai: open chat window")

	cmd("KaiClose", function()
		kai.close()
	end, "kai: close chat window")

	cmd("KaiFocus", function()
		kai.focus()
	end, "kai: focus chat input")

	cmd("KaiSend", function(args)
		-- Range (visual) sends selection as @file context + prompt.
		local text = args.args or ""
		if args.range > 0 then
			local sel = kai.get_visual_text()
			local chip = require("kai.ui.context").current_file_chip()
			if text ~= "" and sel ~= "" then
				text = text .. "\n\nContext " .. chip .. ":\n```\n" .. sel .. "\n```"
			elseif sel ~= "" then
				text = "Explain this " .. chip .. ":\n```\n" .. sel .. "\n```"
			end
		end
		if text == "" then
			-- Fall back to input buffer content, else vim.ui.input.
			local chat_ok, chat = pcall(require, "kai.ui.chat")
			if chat_ok and chat.is_open() then
				local input = chat.get_input_text()
				if input ~= "" then
					chat.send_input()
					return
				end
			end
			vim.ui.input({ prompt = "kai> " }, function(value)
				if value and value ~= "" then
					kai.send(value)
				end
			end)
			return
		end
		kai.send(text)
	end, "kai: send message (visual sends selection)", "*")

	cmd("KaiAbort", function()
		kai.abort()
	end, "kai: abort streaming")

	cmd("KaiNew", function()
		kai.new_session()
	end, "kai: start fresh session")

	cmd("KaiCompact", function(args)
		kai.compact(args.args ~= "" and args.args or nil)
	end, "kai: compact context", "*")

	cmd("KaiModel", function()
		kai.pick_model()
	end, "kai: switch model")

	cmd("KaiThinking", function()
		kai.pick_thinking()
	end, "kai: switch thinking level")

	cmd("KaiStats", function()
		kai.stats()
	end, "kai: show session stats")

	cmd("KaiConfig", function()
		kai.edit_config()
	end, "kai: edit kai/config.json")

	cmd("KaiExport", function(args)
		kai.export_html(args.args ~= "" and args.args or nil)
	end, "kai: export session to HTML", "?")

	cmd("KaiStop", function()
		require("kai.pi").stop()
	end, "kai: stop pi backend")

	cmd("KaiRestart", function()
		local pi = require("kai.pi")
		pi.start({ force = true })
	end, "kai: restart pi backend")
end

function kai.open()
	ensure_attached()
	local pi = require("kai.pi")
	pi.start()
	require("kai.ui.chat").open()
end

function kai.close()
	require("kai.ui.chat").close()
end

function kai.toggle()
	ensure_attached()
	local pi = require("kai.pi")
	local chat = require("kai.ui.chat")
	if chat.is_open() then
		chat.close()
	else
		pi.start()
		chat.open()
	end
end

function kai.focus()
	ensure_attached()
	require("kai.pi").start()
	require("kai.ui.chat").focus_input()
end

---@param text string message to send
function kai.send(text)
	ensure_attached()
	require("kai.pi").start()
	require("kai.ui.chat").submit(text)
end

function kai.abort()
	local pi_ok, pi = pcall(require, "kai.pi")
	if pi_ok then
		pi.abort()
	end
end

function kai.new_session()
	ensure_attached()
	local pi = require("kai.pi")
	local chat = require("kai.ui.chat")
	pi.start()
	if not chat.is_open() then
		chat.open()
	end
	pi.new_session(function(resp)
		if resp.success then
			if resp.data and resp.data.cancelled then
				chat.append_system("new session cancelled by extension")
			else
				chat.append_system("new session started")
			end
		else
			chat.append_system("new_session failed: " .. tostring(resp.error))
		end
	end)
end

---@param instructions string?
function kai.compact(instructions)
	ensure_attached()
	local pi = require("kai.pi")
	local chat = require("kai.ui.chat")
	pi.start()
	pi.compact(instructions, function(resp)
		if not resp.success then
			chat.append_system("compact failed: " .. tostring(resp.error))
		end
		-- compaction_start/end events render the result.
	end)
end

function kai.pick_model()
	ensure_attached()
	local pi = require("kai.pi")
	local chat = require("kai.ui.chat")
	pi.start()
	pi.get_available_models(function(resp)
		if not resp.success then
			vim.notify("[kai] get_available_models: " .. tostring(resp.error), vim.log.levels.ERROR)
			return
		end
		local models = (resp.data and resp.data.models) or {}
		if #models == 0 then
			vim.notify("[kai] no models available", vim.log.levels.WARN)
			return
		end
		local labels = {}
		for i, m in ipairs(models) do
			labels[i] = string.format("%s/%s", m.provider or "?", m.id or "?")
		end
		vim.ui.select(labels, { prompt = "kai model" }, function(choice, idx)
			if not choice or not idx then
				return
			end
			local m = models[idx]
			pi.set_model(m.provider, m.id, function(r2)
				if r2.success then
					require("kai.ui.context").set_model(m)
					chat.append_system("model → `" .. choice .. "`")
				else
					vim.notify("[kai] set_model: " .. tostring(r2.error), vim.log.levels.ERROR)
				end
			end)
		end)
	end)
end

function kai.pick_thinking()
	ensure_attached()
	local pi = require("kai.pi")
	local chat = require("kai.ui.chat")
	pi.start()
	local function choose(levels)
		vim.ui.select(levels, { prompt = "kai thinking level" }, function(choice)
			if not choice then
				return
			end
			pi.set_thinking_level(choice, function(resp)
				if resp.success then
					chat.append_system("thinking → `" .. choice .. "`")
				else
					vim.notify("[kai] set_thinking_level: " .. tostring(resp.error), vim.log.levels.ERROR)
				end
			end)
		end)
	end
	pi.get_available_thinking_levels(function(resp)
		if resp.success and resp.data and resp.data.levels then
			choose(resp.data.levels)
		else
			choose({ "off", "minimal", "low", "medium", "high", "xhigh", "max" })
		end
	end)
end

function kai.stats()
	ensure_attached()
	local pi = require("kai.pi")
	local chat = require("kai.ui.chat")
	pi.start()
	if not chat.is_open() then
		chat.open()
	end
	pi.get_session_stats(function(resp)
		if not resp.success then
			chat.append_system("stats failed: " .. tostring(resp.error))
			return
		end
		local d = resp.data or {}
		require("kai.ui.context").show_stats(chat.chat_buf, d)
		local ctx = d.contextUsage or {}
		chat.append_system(
			string.format(
				"msgs %d · tok %.1fk (in %.1fk/out %.1fk) · $%.4f · ctx %s",
				d.totalMessages or 0,
				(d.tokens and d.tokens.total or 0) / 1000,
				(d.tokens and d.tokens.input or 0) / 1000,
				(d.tokens and d.tokens.output or 0) / 1000,
				d.cost or 0,
				ctx.percent and string.format("%.0f%%", ctx.percent) or "?"
			)
		)
	end)
end

function kai.edit_config()
	local config = require("kai.config")
	local path = config.options.config_file or config.default_config_file()
	vim.fn.mkdir(vim.fs.dirname(path), "p")
	if vim.fn.filereadable(path) == 0 then
		vim.fn.writefile({ "{", '  "pi_cmd": "pi"', "}" }, path)
	end
	vim.cmd("edit " .. vim.fn.fnameescape(path))
end

---@param path string?
function kai.export_html(path)
	ensure_attached()
	local pi = require("kai.pi")
	pi.start()
	pi.export_html(path, function(resp)
		local chat_ok, chat = pcall(require, "kai.ui.chat")
		if resp.success then
			local p = resp.data and resp.data.path or path or "?"
			vim.notify("[kai] exported to " .. p, vim.log.levels.INFO)
			if chat_ok then
				chat.append_system("exported → `" .. p .. "`")
			end
		else
			vim.notify("[kai] export failed: " .. tostring(resp.error), vim.log.levels.ERROR)
		end
	end)
end

---@return string visual selection text (called with range)
function kai.get_visual_text()
	local s = vim.fn.getpos("'<")
	local e = vim.fn.getpos("'>")
	if s[2] == 0 or e[2] == 0 then
		return ""
	end
	local buf = vim.api.nvim_get_current_buf()
	-- getpos returns [bufnum, lnum, col, off]; clamp ordering.
	local srow, scol = s[2] - 1, s[3] - 1
	local erow, ecol = e[2] - 1, e[3]
	if srow > erow or (srow == erow and scol > ecol) then
		srow, scol, erow, ecol = erow, ecol - 1, srow, scol + 1
	end
	local ok, lines = pcall(vim.api.nvim_buf_get_text, buf, srow, scol, erow, ecol, {})
	if not ok then
		return ""
	end
	return table.concat(lines, "\n")
end

return kai
