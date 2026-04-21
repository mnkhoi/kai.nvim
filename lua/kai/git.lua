local M = {}

---Credit: Note this was taken from oil.nvim
---@param path string current path to get the git root
---@return string? root Root of the project if exists
M.get_root = function(path)
	local root = vim.fs.root(0, ".git")
	if not root then
		root = vim.fs.root(
			vim.fs.joinpath(vim.fn.getcwd(vim.api.nvim_get_current_buf(), vim.api.nvim_get_current_win()), "main.py"),
			{
				"pyproject.toml",
				"setup.py",
			}
		)
	end

	return root
end

return M
