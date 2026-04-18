---@class pi.rpc.Base
---@field id string?

---@class pi.rpc.Message : pi.rpc.Base
---@field message string
---@field images pi.type.ImageContent[]|nil

---@class pi.rpc.Prompt : pi.rpc.Message
---@field streamingBehavior "steer" | "followUp" steer queue the message while agent is running - delivered after tool calls before next LLM call. followUp waits until the agent finishes delivered only when agent stops
---@field type "prompt"

---@class pi.rpc.Steer : pi.rpc.Message
---@field type "steer"

---@class pi.rpc.FollowUp : pi.rpc.Message
---@field type "follow_up"

---@class pi.rpc.Abort : pi.rpc.Base
---@field type "abort"

---@class pi.rpc.NewSession : pi.rpc.Base
---@field type "new_session"
---@field parentSession string?

---@alias pi.rpc.Prompting
---| pi.rpc.Prompt # Send user prompt to agent
---| pi.rpc.Steer # Queue sterring message while the agent is running
---| pi.rpc.FollowUp # Queue a follow-up message to be processed after the agent finishes
---| pi.rpc.Abort # Abort the current agent operation
---| pi.rpc.NewSession # Start a fresh session

---@class pi.rpc.GetState : pi.rpc.Base
---@field type "get_state"

---@alias pi.rpc.State
---| pi.rpc.GetState # Get current session state

---@class pi.rpc.SetModel : pi.rpc.Base
---@field type "set_model"
---@field provider string
---@field modelId string

---@class pi.rpc.CycleModel : pi.rpc.Base
---@field type "cycle_model"

---@class pi.rpc.GetAvailableModels : pi.rpc.Base
---@field type "get_available_models"

---@alias pi.rpc.Model
---| pi.rpc.SetModel # Switch to a specific model
---| pi.rpc.CycleModel # Cycle to the next available model
---| pi.rpc.GetAvailableModels # List all configured models

---@class pi.rpc.SetThinkingLevel : pi.rpc.Base
---@field type "set_thinking_level"
---@field level pi.type.ThinkingLevel

---@class pi.rpc.CycleThinkingLevel : pi.rpc.Base
---@field type "cycle_thinking_level"

---@alias pi.rpc.Thinking
---| pi.rpc.SetThinkingLevel # Set the reasoning/thinking level for models that support it
---| pi.rpc.CycleThinkingLevel # Cycle through available thinking level

---@class pi.rpc.SetSteeringMode : pi.rpc.Base
---@field type "set_steering_mode"
---@field mode pi.type.QueueMode

---@class pi.rpc.SetFollowUpMode : pi.rpc.Base
---@field type "set_follow_up_mode"
---@field mode pi.type.QueueMode

---@alias pi.rpc.QueueModes
---| pi.rpc.SetSteeringMode # Control how steering messages are delivered for steer
---| pi.rpc.SetFollowUpMode # Control how steering messages are delivered for follow-up

---@class pi.rpc.Compact
---@field type "compact"
---@field customInstruction string?

---@class pi.rpc.SetAutoCompaction
---@field type "set_auto_compaction"
---@field enabled boolean

---@alias pi.rpc.Compacting
---| pi.rpc.Compact # Manually compact conversation context to reduce token usage
---| pi.rpc.SetAutoCompaction # Enable or disable automatic compaction when context is nearly full

---@class pi.rpc.SetAutoRetry
---@field type "set_auto_retry"
---@field enable boolean

---@class pi.rpc.AbortRetry
---@field type "abort_retry"

---@alias pi.rpc.Retry
---| pi.rpc.SetAutoRetry # Enable or disable automatic retry on transient errors (overloaded, rate limit, 5xx)
---| pi.rpc.AbortRetry # Abort an in-progress retry (cancel the delay and stop retrying)

---@class pi.rpc.RunBash
---@field type "bash"
---@field command string

---@class pi.rpc.AbortBash
---@field type "abort_retry"

---@alias pi.rpc.Bash
---| pi.rpc.RunBash # Execute a shell command and add output to conversation context
---| pi.rpc.AbortBash # Abort a running bash command

---@class pi.rpc.GetSessionStats
---@field type "get_session_stats"

---@class pi.rpc.ExportHTML
---@field type "export_html"
---@field outputPath string?

---@class pi.rpc.SwitchSession
---@field type "switch_session"
---@field sessionPath string

---@class pi.rpc.Fork
---@field type "fork"
---@field entryId string

---@class pi.rpc.GetForkMessages
---@field type "get_fork_messages"

---@class pi.rpc.GetLastAssistantText
---@field type "get_last_assistant_text"

---@class pi.rpc.SetSessionName
---@field type "set_session_name"
---@field name string

---@alias pi.rpc.Session
---| pi.rpc.GetSessionStats # Get token usage, cost statistics, and current context window usage
---| pi.rpc.ExportHTML # Export session to an HTML file
---| pi.rpc.SwitchSession # Load a different session file
---| pi.rpc.Fork # Create a new fork from a previous user message
---| pi.rpc.GetForkMessages # Get user messages available for forking
---| pi.rpc.GetLastAssistantText # Get the text content of the last assistant message
---| pi.rpc.SetSessionName # Set a display name for the current session

---@class pi.rpc.GetMessages
---@field type "get_messages"

---@alias pi.rpc.Messages pi.rpc.GetMessages # Get all messages in the conversation
---
---@class pi.rpc.GetCommands
---@field type "get_commands"

---@alias pi.rpc.Commands pi.rpc.GetCommands # Get available commands

---@alias pi.rpc.request
---| pi.rpc.Prompting
---| pi.rpc.State
---| pi.rpc.Model
---| pi.rpc.Thinking
---| pi.rpc.QueueModes
---| pi.rpc.Compacting
---| pi.rpc.Retry
---| pi.rpc.Bash
---| pi.rpc.Session
---| pi.rpc.Messages
---| pi.rpc.Commands
