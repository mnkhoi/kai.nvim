local M = {}

M.init = function()
	local buf = vim.api.nvim_create_buf(true, true)

	vim.api.nvim_buf_set_name(buf, "KaiChatBuffer")

	M.buf = buf
end

--- Opens chat view and save current buffer to return
M.show_chat = function()
	M.prev_buf = vim.api.nvim_get_current_buf()
	vim.api.nvim_set_current_buf(M.buf)
end

--- Closes chat view and return back to previous buffer
M.close_chat = function()
	vim.api.nvim_set_current_buf(M.prev_buf)
	M.prev_buf = nil
end

return M
