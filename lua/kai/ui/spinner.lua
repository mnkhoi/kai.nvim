---Thinking spinner: animated winbar/virtual-text indicator while the agent streams.
local uv = vim.uv or vim.loop

local M = {}

M.timer = nil
M.frame_idx = 1
M.active = false
M.message = "thinking"

---@param win integer? window to update winbar on (nil = skip winbar)
---@param on_tick fun(frame: string)? extra per-tick callback (e.g. update extmark)
---@param opts {frames: string[]?, interval: integer?, text: string?}?
function M.start(win, on_tick, opts)
	opts = opts or {}
	local cfg_ok, cfg = pcall(require, "kai.config")
	local defaults = { frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }, interval = 80, text = "thinking" }
	if cfg_ok and cfg.options and cfg.options.spinner then
		defaults.frames = cfg.options.spinner.frames or defaults.frames
		defaults.interval = cfg.options.spinner.interval or defaults.interval
		defaults.text = cfg.options.spinner.text or defaults.text
	end
	if opts.frames then
		defaults.frames = opts.frames
	end
	if opts.interval then
		defaults.interval = opts.interval
	end
	if opts.text then
		defaults.text = opts.text
	end
	M.message = defaults.text

	M.stop()
	M.active = true
	M.frame_idx = 1

	M.timer = uv.new_timer()
	if not M.timer then
		return
	end
	M.timer:start(0, defaults.interval, function()
		vim.schedule(function()
			if not M.active then
				return
			end
			M.frame_idx = (M.frame_idx % #defaults.frames) + 1
			local frame = defaults.frames[M.frame_idx]
			if win and vim.api.nvim_win_is_valid(win) then
				pcall(vim.api.nvim_win_set_option, win, "winbar", string.format(" %s %s…", frame, M.message))
			end
			if on_tick then
				pcall(on_tick, frame)
			end
		end)
	end)
	-- Immediate first frame
	if win and vim.api.nvim_win_is_valid(win) then
		pcall(
			vim.api.nvim_win_set_option,
			win,
			"winbar",
			string.format(" %s %s…", defaults.frames[1], M.message)
		)
	end
end

---@param win integer? restore winbar to default status
---@param default_winbar string? text to restore
function M.stop(win, default_winbar)
	M.active = false
	if M.timer then
		pcall(function()
			M.timer:stop()
		end)
		pcall(function()
			M.timer:close()
		end)
		M.timer = nil
	end
	if win and vim.api.nvim_win_is_valid(win) then
		pcall(vim.api.nvim_win_set_option, win, "winbar", default_winbar or " kai · pi ")
	end
end

---@return boolean
function M.is_active()
	return M.active
end

return M
