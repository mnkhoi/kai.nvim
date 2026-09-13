---@class pi.rpc.events.base
---@field type string

---@class pi.rpc.events.agent_start : pi.rpc.events.base
---@field type "agent_start"

---@class pi.rpc.events.agent_end : pi.rpc.events.base
---@field type "agent_end"
---@field messages pi.type.AgentMessage[]
---@field willRetry boolean?

---@class pi.rpc.events.agent_settled : pi.rpc.events.base
---@field type "agent_settled"

---@class pi.rpc.events.turn_start : pi.rpc.events.base
---@field type "turn_start"

---@class pi.rpc.events.turn_end : pi.rpc.events.base
---@field type "turn_end"
---@field message pi.type.AgentMessage
---@field toolResults pi.type.ToolResultMessage[]

---@class pi.rpc.events.message_start : pi.rpc.events.base
---@field type "message_start"
---@field message pi.type.AgentMessage

---@class pi.rpc.events.message_update : pi.rpc.events.base
---@field type "message_update"
---@field usage pi.type.Usage?
---@field assistantMessageEvent pi.type.AssistantMessageEvent

---@class pi.rpc.events.message_end : pi.rpc.events.base
---@field type "message_end"
---@field message pi.type.AgentMessage

---@class pi.rpc.events.bash_execution_update : pi.rpc.events.base
---@field type "bash_execution_update"
---@field id string?
---@field delta string

---@class pi.rpc.events.tool_execution_start : pi.rpc.events.base
---@field type "tool_execution_start"
---@field toolCallId string
---@field toolName string
---@field args any

---@class pi.rpc.events.tool_execution_update : pi.rpc.events.base
---@field type "tool_execution_update"
---@field toolCallId string
---@field toolName string
---@field args any
---@field partialResult any

---@class pi.rpc.events.tool_execution_end : pi.rpc.events.base
---@field type "tool_execution_end"
---@field toolCallId string
---@field toolName string
---@field result any
---@field isError boolean

---@class pi.rpc.events.queue_update : pi.rpc.events.base
---@field type "queue_update"
---@field steering string[]
---@field followUp string[]

---@class pi.rpc.events.compaction_start : pi.rpc.events.base
---@field type "compaction_start"
---@field reason "manual"|"threshold"|"overflow"

---@class pi.rpc.events.compaction_end : pi.rpc.events.base
---@field type "compaction_end"
---@field reason "manual"|"threshold"|"overflow"
---@field result pi.type.CompactionResult?
---@field aborted boolean
---@field willRetry boolean?
---@field errorMessage string?

---@class pi.rpc.events.auto_retry_start : pi.rpc.events.base
---@field type "auto_retry_start"
---@field attempt number
---@field maxAttempts number
---@field delayMs number
---@field errorMessage string

---@class pi.rpc.events.auto_retry_end : pi.rpc.events.base
---@field type "auto_retry_end"
---@field success boolean
---@field attempt number
---@field finalError? string

---@class pi.rpc.events.summarization_retry_scheduled : pi.rpc.events.base
---@field type "summarization_retry_scheduled"
---@field attempt number
---@field maxAttempts number
---@field delayMs number
---@field errorMessage string

---@class pi.rpc.events.summarization_retry_attempt_start : pi.rpc.events.base
---@field type "summarization_retry_attempt_start"
---@field source string
---@field reason string?

---@class pi.rpc.events.summarization_retry_finished : pi.rpc.events.base
---@field type "summarization_retry_finished"

---@class pi.rpc.events.extension_error : pi.rpc.events.base
---@field type "extension_error"
---@field extensionPath string
---@field event string
---@field error string

---@alias pi.rpc.events
---| pi.rpc.events.agent_start
---| pi.rpc.events.agent_end
---| pi.rpc.events.agent_settled
---| pi.rpc.events.turn_start
---| pi.rpc.events.turn_end
---| pi.rpc.events.message_start
---| pi.rpc.events.message_update
---| pi.rpc.events.message_end
---| pi.rpc.events.bash_execution_update
---| pi.rpc.events.tool_execution_start
---| pi.rpc.events.tool_execution_update
---| pi.rpc.events.tool_execution_end
---| pi.rpc.events.queue_update
---| pi.rpc.events.compaction_start
---| pi.rpc.events.compaction_end
---| pi.rpc.events.auto_retry_start
---| pi.rpc.events.auto_retry_end
---| pi.rpc.events.summarization_retry_scheduled
---| pi.rpc.events.summarization_retry_attempt_start
---| pi.rpc.events.summarization_retry_finished
---| pi.rpc.events.extension_error

local M = {}

---@type table<string, boolean> O(1) lookup of event type -> true
M.registered_events = {
	["agent_start"] = true,
	["agent_end"] = true,
	["agent_settled"] = true,
	["turn_start"] = true,
	["turn_end"] = true,
	["message_start"] = true,
	["message_update"] = true,
	["message_end"] = true,
	["bash_execution_update"] = true,
	["tool_execution_start"] = true,
	["tool_execution_update"] = true,
	["tool_execution_end"] = true,
	["queue_update"] = true,
	["compaction_start"] = true,
	["compaction_end"] = true,
	["auto_retry_start"] = true,
	["auto_retry_end"] = true,
	["summarization_retry_scheduled"] = true,
	["summarization_retry_attempt_start"] = true,
	["summarization_retry_finished"] = true,
	["extension_error"] = true,
}

---@param data table data after deserializing through vim.json.decode
---@return pi.rpc.events? event if it matches a known event type, else nil
function M.match(data)
	if type(data) ~= "table" then
		return nil
	end
	if type(data.type) == "string" and M.registered_events[data.type] then
		return data
	end
	return nil
end

return M
