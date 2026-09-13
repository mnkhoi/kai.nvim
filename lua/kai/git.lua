local M = {}

---Find the enclosing project root for `path` (or current buffer).
---Credit: adapted from oil.nvim.
---@param path string? starting path (file or dir); defaults to current buffer dir
---@return string? root git root, or language-marker root, or nil
function M.get_root(path)
	if not path or path == "" then
		local buf = vim.api.nvim_buf_get_name(0)
		if buf ~= "" then
			path = vim.fs.dirname(buf)
		else
			path = vim.fn.getcwd()
		end
	end
	-- Normalize file -> dir.
	local stat = vim.uv and vim.uv.fs_stat and vim.uv.fs_stat(path)
	if stat and stat.type == "file" then
		path = vim.fs.dirname(path)
	end

	local ok, root = pcall(vim.fs.root, path, ".git")
	if ok and root then
		return root
	end
	local ok2, alt = pcall(vim.fs.root, path, { "pyproject.toml", "setup.py", "package.json", "go.mod", "Cargo.toml" })
	if ok2 and alt then
		return alt
	end
	return nil
end

return M
