local M = {}

---@param dir string
---@param mode? integer
M.mkdirp = function(dir, mode)
	mode = mode or 493
	local mod = ""
	local path = dir
	while vim.fn.isdirectory(path) == 0 do
		mod = mod .. ":h"
		path = vim.fn.fnamemodify(dir, mod)
	end
	while mod ~= "" do
		mod = mod:sub(3)
		path = vim.fn.fnamemodify(dir, mod)
		uv.fs_mkdir(path, mode)
	end
end

return M
