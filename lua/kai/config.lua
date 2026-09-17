local M = {}

---@class kai.window.opts
---@field placement "right"|"left"|"float" Where to open the chat window
---@field width integer Width for vertical splits
---@field input_height integer Height of the input window
---@field border string Border style for float mode

---@class kai.spinner.opts
---@field frames string[] Spinner frames
---@field interval integer ms between frames
---@field text string Prefix text while thinking

---@class kai.context.opts
---@field enabled boolean Show virtual-text context chips
---@field show_stats boolean Show tokens/cost virtual text at top of chat

---@class kai.opts
---@field pi_cmd string Binary to spawn (default "pi")
---@field pi_args string[] Extra CLI args prepended before --mode rpc (e.g. {"--provider","anthropic"})
---@field model string Model we want to connect to (default "big-pickle")
---@field thinking "off"|"minimal"|"low"|"medium"|"high"|"xhigh"|"max" Thinking level of the model (default "off")
---@field cwd string? Working directory for pi (default: git root of current file or vim cwd)
---@field no_session boolean If true pass --no-session (ephemeral)
---@field session_dir string? Custom session storage dir (--session-dir)
---@field session_name string? Initial display name (--name)
---@field approve_project boolean? nil=leave default, true=--approve, false=--no-approve
---@field extensions string[] Extra -e/--extension values
---@field no_extensions boolean Disable extension discovery
---@field window kai.window.opts
---@field spinner kai.spinner.opts
---@field context kai.context.opts
---@field log_level integer vim.log.levels
---@field config_file string? Path to kai/config.json (default stdpath("config")/kai/config.json)

---@type kai.opts
M.defaults = {
	pi_cmd = "pi",
	pi_args = {},
	cwd = nil,
	no_session = false,
	session_dir = nil,
	session_name = nil,
	approve_project = nil,
	extensions = {},
	no_extensions = false,
	window = {
		placement = "right",
		width = 60,
		input_height = 2,
		border = "rounded",
	},
	spinner = {
		frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" },
		interval = 80,
		text = "thinking",
	},
	context = {
		enabled = true,
		show_stats = true,
	},
	log_level = vim.log.levels.WARN,
	config_file = nil,
	model = "big-pickle",
	thinking = "off",
}

---@type kai.opts
M.options = vim.deepcopy(M.defaults)

---Resolve default config.json path.
---@return string
function M.default_config_file()
	return vim.fs.joinpath(vim.fn.stdpath("config"), "kai", "config.json")
end

---Load optional JSON config file and return it as a table ({} on missing/invalid).
---@param path string?
---@return table
function M.load_json_file(path)
	path = path or M.options.config_file or M.default_config_file()
	local ok, content = pcall(vim.fn.readfile, path)
	if not ok or not content or #content == 0 then
		return {}
	end
	local joined = table.concat(content, "\n")
	if joined:match("^%s*$") then
		return {}
	end
	local ok2, decoded = pcall(vim.json.decode, joined)
	if not ok2 or type(decoded) ~= "table" then
		vim.notify("[kai] invalid JSON in " .. path, vim.log.levels.WARN)
		return {}
	end
	return decoded
end

---Deep-merge user opts over defaults (with optional config.json as middle layer).
---@param opts kai.opts?
---@return kai.opts
function M.setup(opts)
	-- 1. start from defaults
	M.options = vim.deepcopy(M.defaults)
	-- 2. merge config.json if present (so `:KaiConfig` file works without setup args)
	local json_opts = M.load_json_file(opts and opts.config_file or M.default_config_file())
	if type(json_opts) == "table" and not vim.tbl_isempty(json_opts) then
		M.options = vim.tbl_deep_extend("force", M.options, json_opts)
	end
	-- 3. explicit setup() opts win
	if opts then
		M.options = vim.tbl_deep_extend("force", M.options, opts)
	end
	if M.options.config_file == nil then
		M.options.config_file = M.default_config_file()
	end
	local logger = require("kai.logger")
	logger.level = M.options.log_level or vim.log.levels.WARN
	return M.options
end

---Build the full argv for `pi --mode rpc`.
---@return string[] argv (without binary)
function M.build_pi_args()
	local o = M.options
	---@type string[]
	local args = { "--mode", "rpc", "--model", o.model, "--thinking", o.thinking }
	for _, a in ipairs(o.pi_args or {}) do
		args[#args + 1] = a
	end
	if o.no_session then
		args[#args + 1] = "--no-session"
	end
	if o.session_dir and o.session_dir ~= "" then
		args[#args + 1] = "--session-dir"
		args[#args + 1] = o.session_dir
	end
	if o.session_name and o.session_name ~= "" then
		args[#args + 1] = "--name"
		args[#args + 1] = o.session_name
	end
	if o.approve_project == true then
		args[#args + 1] = "--approve"
	elseif o.approve_project == false then
		args[#args + 1] = "--no-approve"
	end
	if o.no_extensions then
		args[#args + 1] = "--no-extensions"
	end
	for _, e in ipairs(o.extensions or {}) do
		args[#args + 1] = "--extension"
		args[#args + 1] = e
	end
	return args
end

---Resolve cwd for the pi process.
---@return string
function M.resolve_cwd()
	if M.options.cwd and M.options.cwd ~= "" then
		return M.options.cwd
	end
	local ok, git = pcall(require, "kai.git")
	if ok and git.get_root then
		local cur = vim.fn.expand("%:p:h")
		if cur == "" then
			cur = vim.fn.getcwd()
		end
		local root = git.get_root(cur)
		if root and root ~= "" then
			return root
		end
	end
	return vim.fn.getcwd()
end

return M
