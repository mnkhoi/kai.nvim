local logger = require("kai.logger")
local events = require("kai.rpc.events")
local request = require("kai.rpc.request")
local response = require("kai.rpc.response")

local M = {}

---@type vim.json.decode.Opts
local decode_opts = {
	luanil = { object = true, array = true },
}

---@param obj table RPC command/table to send
---@return string? line JSONL line without trailing newline, nil on failure
function M.serialize(obj)
	local ok, encoded = pcall(vim.json.encode, obj)
	if not ok or not encoded then
		logger.error("Failed to encode RPC command: %s", vim.inspect(obj))
		return nil
	end
	return encoded
end

---@param line string single JSONL record (no trailing newline, optional trailing \r stripped by caller)
---@return table? data decoded table or nil
---@return string? kind "response"|"events"|"extension_ui_request"|"request"|"unknown"
function M.deserialize(line)
	if line == nil or line == "" then
		return nil, nil
	end
	-- Strict LF framing: strip one optional trailing \r (accept \r\n input).
	if line:sub(-1) == "\r" then
		line = line:sub(1, -2)
		if line == "" then
			return nil, nil
		end
	end
	local ok, data = pcall(vim.json.decode, line, decode_opts)
	if not ok or type(data) ~= "table" or vim.tbl_isempty(data) then
		if not ok then
			logger.warn("Failed to decode RPC line: %s", line:sub(1, 200))
		end
		return nil, nil
	end

	-- Order matters: response first (type=="response"), then extension UI,
	-- then agent events, then echo of our own commands (shouldn't normally arrive).
	if response.match(data) then
		return data, "response"
	end
	if data.type == "extension_ui_request" then
		return data, "extension_ui_request"
	end
	if events.match(data) then
		return data, "events"
	end
	if request.match(data) then
		return data, "request"
	end
	logger.warn("Unknown RPC type: %s", tostring(data.type))
	return data, "unknown"
end

---Incremental LF-delimited framer. Feed raw stdout chunks, get complete lines.
---@class kai.rpc.framer
---@field buf string
local Framer = {}
Framer.__index = Framer

---Create a new framer.
---@return kai.rpc.framer
function M.new_framer()
	return setmetatable({ buf = "" }, Framer)
end

---@param chunk string? raw bytes from uv (nil/empty = EOF tick)
---@return string[] lines complete LF-delimited records (without delimiter)
function Framer:feed(chunk)
	local lines = {}
	if chunk and #chunk > 0 then
		self.buf = self.buf .. chunk
	end
	while true do
		-- Strict: split on \n only (never on U+2028/U+2029 inside JSON strings).
		local idx = self.buf:find("\n", 1, true)
		if not idx then
			break
		end
		local line = self.buf:sub(1, idx - 1)
		self.buf = self.buf:sub(idx + 1)
		lines[#lines + 1] = line
	end
	return lines
end

M.Framer = Framer

return M
