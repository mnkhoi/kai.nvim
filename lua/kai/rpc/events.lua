---@class pi.rpc.events.base
---@field type string

---@class pi.rpc.events.agent_start : pi.rpc.events.base
---@field type "agent_start"

---@class pi.rpc.events.agent_end : pi.rpc.events.base
---@field type "agent_end"
---@field messages pi.type.AgentMessage[]

---@class pi.rpc.events.turn_start : pi.rpc.events.base
---@field type "turn_start"
---@field turnIndex number
---@field timestamp number

---@class pi.rpc.events.turn_end : pi.rpc.events.base
---@field type "turn_end"
---@field turnIndex number
---@field messages pi.type.AgentMessage
---@field toolResults pi.type.ToolResultMessage[]

---@class pi.rpc.events.message_start : pi.rpc.events.base
---@field type "message_start"
---@field message pi.type.AgentMessage

---@class pi.rpc.events.message_update : pi.rpc.events.base
---@field type "message_end"
---@field message pi.type.AgentMessage
---@field assistantMessageEvent pi.type.AssistantMessageEvent

---@class pi.rpc.events.message_end : pi.rpc.events.base
---@field type "message_end"
---@field message pi.type.AgentMessage

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
---@field willRetry boolean
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

---@class pi.rpc.events.extension_error : pi.rpc.events.base
---@field type "extension_error"
---@field extensionPath string
---@field event string
---@field error string
