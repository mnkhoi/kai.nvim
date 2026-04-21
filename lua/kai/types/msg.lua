---@alias pi.type.ThinkingLevel "minimal" | "low" | "medium" | "high" | "xhigh"
---@alias pi.type.QueueMode "all" | "one-at-a-time"
---@alias pi.type.StopReason "stop" | "length" | "toolUse" | "error" | "aborted"

--- :start: CONTENT TYPES

---@class pi.type.TextContent
---@field type "text"
---@field text string
---@field textSignature? string

---@class pi.type.ThinkingContent
---@field type "thinking"
---@field thinking string
---@field thinkingSignature? string
---@field redacted? boolean

---@class pi.type.ImageContent
---@field type "image"
---@field data string
---@field mimeType string

--- :end: CONTENT TYPES

--- :start: OTHER TYPES

---@class pi.type.ToolCall
---@field type "toolCall"
---@field id string
---@field name string
---@field arguments table<string,any>
---@field thoughtSignature? string

---@class pi.type.Usage
---@field input number
---@field output number
---@field cacheRead number
---@field cacheWrite number
---@field totalTokens number
---@field cost {input: number, output:number, cacheRead: number, cacheWrite: number, total: number}

--- :end: OTHER TYPES

--- :start: MESSAGES TYPE

---@class pi.type.UserMessage
---@field role "user"
---@field content string | (pi.type.TextContent|pi.type.ImageContent)[]
---@field timestamp number # Unix timestamp in milliseconds

---@class pi.type.AssistantMessage
---@field role "assistant"
---@field content (pi.type.TextContent|pi.type.ThinkingContent|pi.type.ToolCall)[]
---@field api pi.type.Api
---@field provider pi.type.Provider
---@field model string
---@field responseId? string
---@field usage pi.type.Usage
---@field stopReason pi.type.StopReason
---@field errorMessage? string
---@field timestamp number

---@class pi.type.ToolResultMessage
---@field role "toolResult"
---@field toolCallId string
---@field toolName string
---@field content (pi.type.TextContent|pi.type.ImageContent)[]
---@field details? any
---@field isError boolean
---@field timestamp number

---@alias pi.type.Message pi.type.UserMessage|pi.type.AssistantMessage|pi.type.ToolResultMessage

---@alias pi.type.AgentMessage pi.type.Message | {}

--- :end: MESSAGES TYPE

--- :start: FUNDAMENTAL TYPE

---@alias pi.type.SourceScope "user"|"project"|"temporary"
---@alias pi.type.SourceOrigin "package"|"top-level"

---@class pi.type.SourceInfo
---@field path string
---@field source string
---@field scope pi.type.SourceScope
---@field origin pi.type.SourceOrigin
---@field baseDir? string

---@class pi.type.Model
---@field id string
---@field name string
---@field api pi.type.Api
---@field provider pi.type.Provider
---@field baseUrl string
---@field reasoning boolean
---@field input ("text"|"image")[]
---@field cost {input: number, output: number, cacheRead: number, cacheWrite: number}
---@field contextWindow number
---@field maxTokens number
---@field headers table<string, string>?
---TODO: future add openAi compat api. Look under ai/src/types.ts in pi-mono for more idea

---@class pi.type.ContextUsage
---@field tokens number?
---@field contextWindow number
---@field percent number?

--- :end: FUNDAMENTAL TYPE

---@class pi.type.RpcSessionState
---@field model pi.type.Model
---@field thinkingLevel pi.type.ThinkingLevel
---@field isStreaming boolean
---@field isCompacting boolean
---@field steeringMode "all"|"one-at-a-time"
---@field followUpMode "all"|"one-at-a-time"
---@field sessionFile string?
---@field sessionId string
---@field sessionName string?
---@field autoCompactionEnabled boolean
---@field messageCount number
---@field pendingMessageCount number

---@class pi.type.CompactionResult
---@field summary string
---@field firstKeptEntryId string
---@field tokensBefore number
---@field details? any

---@class pi.type.BashResult
---@field output string
---@field exitCode? number
---@field cancelled boolean
---@field truncated boolean
---@field fullOutputPath? string

---@class pi.type.SessionStats
---@field sessionFile? string
---@field sessionId string
---@field userMessages number
---@field assistantMessages number
---@field toolCalls number
---@field toolResults number
---@field totalMessages number
---@field tokens {input: number, output: number, cacheRead: number, cacheWrite: number, total: number}
---@field cost number
---@field contextUsage? pi.type.ContextUsage

---@class pi.type.RpcSlashCommand
---@field name string
---@field description? string
---@field source "extension"|"prompt"|"skill"
---@field sourceInfo pi.type.SourceInfo
