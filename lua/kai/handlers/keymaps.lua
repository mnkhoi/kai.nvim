local M

---@class kai.keymap.opts
---@field open_chat string? opens the current chat view (default: "<leader>ko" )

---@type kai.keymap.opts
local default_keymap_opts = {
	open_chat = "<leader>ko",
}

---@param opts kai.keymap.opts
M.setup = function(session, opts)
	local keymap_opts = vim.tbl_extend("force", default_keymap_opts, opts)

	vim.keymap.set("n", keymap_opts.open_chat, session:chat.show_chat)
end

return M
