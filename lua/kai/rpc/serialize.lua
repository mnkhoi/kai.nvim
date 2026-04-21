local logger = require("kai.logger")
local events = require("kai.rpc.events")
local request = require("kai.rpc.request")
local response = require("kai.rpc.response")

local M = {}

---@type vim.json.decode.Opts
local decode_opts = {
	luanil = { object = true, array = true },
	skip_comments = true,
}

---@type vim.json.encode.Opts
local encode_opts = {
	escape_slash = true,
}

---@param msg string message chunk from picode lib uv; \n delimited
---@return [pi.rpc.request|pi.rpc.response|pi.rpc.events, "request"|"response"|"events"]?
M.deserialize = function(msg)
	---@type boolean, table
	local success, data = pcall(vim.json.decode, msg, decode_opts)

	if not success or not data or vim.tbl_isempty(data) then
		return nil
	end

	if events.match(data) then
		return { data, "events" }
	elseif request.match(data) then
		return { data, "request" }
	elseif response.match(data) then
		return { data, "response" }
	else
		logger.warn("Invalid type")
	end
end

return M
