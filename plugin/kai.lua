-- kai.nvim entry point: user commands are created in kai.setup(),
-- but define them lazily here too so `:KaiToggle` works without explicit setup.
local function ensure_setup()
	local ok, kai = pcall(require, "kai")
	if not ok then
		return nil
	end
	if not vim.g.kai_setup_done then
		vim.g.kai_setup_done = true
		kai.setup({})
	end
	return kai
end

for _, name in ipairs({
	"KaiToggle",
	"KaiOpen",
	"KaiClose",
	"KaiFocus",
	"KaiSend",
	"KaiAbort",
	"KaiNew",
	"KaiCompact",
	"KaiModel",
	"KaiThinking",
	"KaiStats",
	"KaiConfig",
	"KaiExport",
	"KaiStop",
	"KaiRestart",
}) do
	if vim.fn.exists(":" .. name) == 0 then
		vim.api.nvim_create_user_command(name, function(args)
			local kai = ensure_setup()
			if not kai then
				vim.notify("[kai] failed to load", vim.log.levels.ERROR)
				return
			end
			-- setup() recreated the real commands; re-dispatch.
			if vim.fn.exists(":" .. name) == 2 then
				local cmd = name .. (args.args ~= "" and (" " .. args.args) or "")
				if args.range > 0 then
					cmd = string.format("%d,%d%s", args.line1, args.line2, cmd)
				end
				vim.cmd(cmd)
			end
		end, { nargs = "*", range = true, desc = "kai: lazy bootstrap" })
	end
end
