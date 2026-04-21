---@class pi.rpc.res.base
---@field id string?
---@field type "response"
---@field command string
---@field success boolean

---@class pi.rpc.res.prompt : pi.rpc.res.base
---@field command "prompt"
---@field success true

---@class pi.rpc.res.steer : pi.rpc.res.base
---@field command "steer"
---@field success true

---@class pi.rpc.res.follow_up : pi.rpc.res.base
---@field command "follow_up"
---@field success true

---@class pi.rpc.res.abort : pi.rpc.res.base
---@field command "abort"
---@field success true

---@class pi.rpc.res.new_session : pi.rpc.res.base
---@field command "new_session"
---@field success true
---@field data { cancelled: boolean }

---@alias pi.rpc.res.prompting
---| pi.rpc.res.prompt
---| pi.rpc.res.steer
---| pi.rpc.res.follow_up
---| pi.rpc.res.abort
---| pi.rpc.res.new_session

---@class pi.rpc.res.get_state : pi.rpc.res.base
---@field command "get_state"
---@field success true
---@field data pi.type.RpcSessionState

---@alias pi.rpc.res.state
---| pi.rpc.res.get_state

---@class pi.rpc.res.set_model : pi.rpc.res.base
---@field command "set_model"
---@field success true
---@field data pi.type.Model

---@class pi.rpc.res.cycle_model : pi.rpc.res.base
---@field command "cycle_model"
---@field success true
---@field data {model:pi.type.Model, thinkingLevel: pi.type.ThinkingLevel, isScoped: boolean}?

---@class pi.rpc.res.get_available_models : pi.rpc.res.base
---@field command "get_available_models"
---@field success true
---@field data {models: pi.type.Model[]}

---@alias pi.rpc.res.model
---| pi.rpc.res.set_model
---| pi.rpc.res.cycle_model
---| pi.rpc.res.get_available_models

---@class pi.rpc.res.set_thinking_level : pi.rpc.res.base
---@field command "set_thinking_level"
---@field success true

---@class pi.rpc.res.cycle_thinking_level : pi.rpc.res.base
---@field command "cycle_thinking_level"
---@field success true
---@field data {level: pi.type.ThinkingLevel}?

---@alias pi.rpc.res.thinking
---| pi.rpc.req.set_thinking_level
---| pi.rpc.req.cycle_thinking_level

---@class pi.rpc.res.set_steering_mode : pi.rpc.res.base
---@field command "set_steering_mode"
---@field success true

---@class pi.rpc.res.set_follow_up_mode : pi.rpc.res.base
---@field command "set_follow_up_mode"
---@field success true

---@alias pi.rpc.res.queue_modes
---| pi.rpc.res.set_steering_mode
---| pi.rpc.res.set_follow_up_mode

---@class pi.rpc.res.compact : pi.rpc.res.base
---@field command "compact"
---@field success true
---@field data pi.type.CompactionResult

---@class pi.rpc.res.set_auto_compaction : pi.rpc.res.base
---@field command "set_auto_compaction"
---@field success true

---@alias pi.rpc.res.compacting
---| pi.rpc.res.compact
---| pi.rpc.res.set_auto_compaction

---@class pi.rpc.res.set_auto_retry : pi.rpc.res.base
---@field command "set_auto_retry"
---@field success true

---@class pi.rpc.res.abort_retry : pi.rpc.res.base
---@field command "abort_retry"
---@field success true

---@alias pi.rpc.res.retry
---| pi.rpc.res.set_auto_retry
---| pi.rpc.res.abort_retry

---@class pi.rpc.res.run_bash : pi.rpc.res.base
---@field command "bash"
---@field success true
---@field data pi.type.BashResult

---@class pi.rpc.res.abort_bash : pi.rpc.res.base
---@field command "abort_bash"
---@field success true

---@alias pi.rpc.res.bash
---| pi.rpc.res.run_bash
---| pi.rpc.req.abort_bash

---@class pi.rpc.res.get_session_stats : pi.rpc.res.base
---@field command "get_session_stats"
---@field success true
---@field data pi.type.SessionStats

---@class pi.rpc.res.export_html : pi.rpc.res.base
---@field command "export_html"
---@field success true
---@field data {path:string}

---@class pi.rpc.res.switch_session : pi.rpc.res.base
---@field command "switch_session"
---@field success true
---@field data {cancelled:boolean}

---@class pi.rpc.res.fork : pi.rpc.res.base
---@field command "fork"
---@field success true
---@field data {text: string, cancelled: boolean}

---@class pi.rpc.res.clone : pi.rpc.res.base
---@field command "clone"
---@field success true
---@field data {cancelled: boolean}

---@class pi.rpc.res.get_fork_messages : pi.rpc.res.base
---@field command "get_fork_messages"
---@field success true
---@field data {message: {entryId: string, text: string}[]}

---@class pi.rpc.res.get_last_assistant_text : pi.rpc.res.base
---@field command "get_last_assistant_text"
---@field success true
---@field data {text: string?}

---@class pi.rpc.res.set_session_name : pi.rpc.res.base
---@field command "set_session_name"
---@field success true

---@alias pi.rpc.res.session
---| pi.rpc.res.get_session_stats
---| pi.rpc.res.export_html
---| pi.rpc.res.switch_session
---| pi.rpc.res.fork
---| pi.rpc.res.get_fork_messages
---| pi.rpc.res.get_last_assistant_text
---| pi.rpc.res.set_session_name

---@class pi.rpc.res.get_messages : pi.rpc.res.base
---@field command "get_messages"
---@field success true
---@field data {messages: pi.type.AgentMessage[]}

---@alias pi.rpc.res.messages pi.rpc.res.get_messages

---@class pi.rpc.res.get_commands : pi.rpc.res.base
---@field command "get_commands"
---@field success true
---@field data {commands: pi.type.RpcSlashCommand[]}

---@alias pi.rpc.res.commands pi.rpc.res.get_commands

---@class pi.rpc.res.error : pi.rpc.res.base
---@field command string
---@field success false
---@field error string

---@alias pi.rpc.response
---| pi.rpc.res.prompting
---| pi.rpc.res.state
---| pi.rpc.res.model
---| pi.rpc.res.thinking
---| pi.rpc.res.queue_modes
---| pi.rpc.res.compacting
---| pi.rpc.res.retry
---| pi.rpc.res.bash
---| pi.rpc.res.session
---| pi.rpc.res.messages
---| pi.rpc.res.commands
---| pi.rpc.res.error
