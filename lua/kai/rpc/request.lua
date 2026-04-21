---@class pi.rpc.req.base
---@field id string?

---@class pi.rpc.req.message : pi.rpc.req.base
---@field message string
---@field images pi.type.ImageContent[]|nil

---@class pi.rpc.req.prompt : pi.rpc.req.message
---@field streamingBehavior "steer" | "followUp" steer queue the message while agent is running - delivered after tool calls before next LLM call. followUp waits until the agent finishes delivered only when agent stops
---@field type "prompt"

---@class pi.rpc.req.steer : pi.rpc.req.message
---@field type "steer"

---@class pi.rpc.req.follow_up : pi.rpc.req.message
---@field type "follow_up"

---@class pi.rpc.req.abort : pi.rpc.req.base
---@field type "abort"

---@class pi.rpc.req.new_session : pi.rpc.req.base
---@field type "new_session"
---@field parentSession string?

---@alias pi.rpc.req.prompting
---| pi.rpc.req.prompt # Send user prompt to agent
---| pi.rpc.req.steer # Queue sterring message while the agent is running
---| pi.rpc.req.follow_up # Queue a follow-up message to be processed after the agent finishes
---| pi.rpc.req.abort # Abort the current agent operation
---| pi.rpc.req.new_session # Start a fresh session

---@class pi.rpc.req.get_state : pi.rpc.req.base
---@field type "get_state"

---@alias pi.rpc.req.state
---| pi.rpc.req.get_state # Get current session state

---@class pi.rpc.req.set_model : pi.rpc.req.base
---@field type "set_model"
---@field provider string
---@field modelId string

---@class pi.rpc.req.cycle_model : pi.rpc.req.base
---@field type "cycle_model"

---@class pi.rpc.req.get_available_models : pi.rpc.req.base
---@field type "get_available_models"

---@alias pi.rpc.req.model
---| pi.rpc.req.set_model # Switch to a specific model
---| pi.rpc.req.cycle_model # Cycle to the next available model
---| pi.rpc.req.get_available_models # List all configured models

---@class pi.rpc.req.set_thinking_level : pi.rpc.req.base
---@field type "set_thinking_level"
---@field level pi.type.ThinkingLevel

---@class pi.rpc.req.cycle_thinking_level : pi.rpc.req.base
---@field type "cycle_thinking_level"

---@alias pi.rpc.req.thinking
---| pi.rpc.req.set_thinking_level # Set the reasoning/thinking level for models that support it
---| pi.rpc.req.cycle_thinking_level # Cycle through available thinking level

---@class pi.rpc.req.set_steering_mode : pi.rpc.req.base
---@field type "set_steering_mode"
---@field mode pi.type.QueueMode

---@class pi.rpc.req.set_follow_up_mode : pi.rpc.req.base
---@field type "set_follow_up_mode"
---@field mode pi.type.QueueMode

---@alias pi.rpc.req.queue_modes
---| pi.rpc.req.set_steering_mode # Control how steering messages are delivered for steer
---| pi.rpc.req.set_follow_up_mode # Control how steering messages are delivered for follow-up

---@class pi.rpc.req.compact
---@field type "compact"
---@field customInstruction string?

---@class pi.rpc.req.set_auto_compaction
---@field type "set_auto_compaction"
---@field enabled boolean

---@alias pi.rpc.req.compacting
---| pi.rpc.req.compact # Manually compact conversation context to reduce token usage
---| pi.rpc.req.set_auto_compaction # Enable or disable automatic compaction when context is nearly full

---@class pi.rpc.req.set_auto_retry
---@field type "set_auto_retry"
---@field enable boolean

---@class pi.rpc.req.abort_retry
---@field type "abort_retry"

---@alias pi.rpc.req.retry
---| pi.rpc.req.set_auto_retry # Enable or disable automatic retry on transient errors (overloaded, rate limit, 5xx)
---| pi.rpc.req.abort_retry # Abort an in-progress retry (cancel the delay and stop retrying)

---@class pi.rpc.req.run_bash
---@field type "bash"
---@field command string

---@class pi.rpc.req.abort_bash
---@field type "abort_retry"

---@alias pi.rpc.req.bash
---| pi.rpc.req.run_bash # Execute a shell command and add output to conversation context
---| pi.rpc.req.abort_bash # Abort a running bash command

---@class pi.rpc.req.get_session_stats
---@field type "get_session_stats"

---@class pi.rpc.req.export_html
---@field type "export_html"
---@field outputPath string?

---@class pi.rpc.req.switch_session
---@field type "switch_session"
---@field sessionPath string

---@class pi.rpc.req.fork
---@field type "fork"
---@field entryId string

---@class pi.rpc.req.get_fork_messages
---@field type "get_fork_messages"

---@class pi.rpc.req.get_last_assistant_text
---@field type "get_last_assistant_text"

---@class pi.rpc.req.set_session_name
---@field type "set_session_name"
---@field name string

---@alias pi.rpc.req.session
---| pi.rpc.req.get_session_stats # Get token usage, cost statistics, and current context window usage
---| pi.rpc.req.export_html # Export session to an HTML file
---| pi.rpc.req.switch_session # Load a different session file
---| pi.rpc.req.fork # Create a new fork from a previous user message
---| pi.rpc.req.get_fork_messages # Get user messages available for forking
---| pi.rpc.req.get_last_assistant_text # Get the text content of the last assistant message
---| pi.rpc.req.set_session_name # Set a display name for the current session

---@class pi.rpc.req.get_messages
---@field type "get_messages"

---@alias pi.rpc.req.messages pi.rpc.req.get_messages # Get all messages in the conversation
---
---@class pi.rpc.req.get_commands
---@field type "get_commands"

---@alias pi.rpc.req.commands pi.rpc.req.get_commands # Get available commands

---@alias pi.rpc.request
---| pi.rpc.req.prompting
---| pi.rpc.req.state
---| pi.rpc.req.model
---| pi.rpc.req.thinking
---| pi.rpc.req.queue_modes
---| pi.rpc.req.compacting
---| pi.rpc.req.retry
---| pi.rpc.req.bash
---| pi.rpc.req.session
---| pi.rpc.req.messages
---| pi.rpc.req.commands
