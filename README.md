# kai - NVIM Coding Agent

Neovim frontend for [pi](https://pi.dev) via `pi --mode rpc` (LF-delimited JSONL over stdin/stdout).

> [!NOTICE]
> This is just a fun project

## Planning

- [x] RPC Protocol for pi-mono (`lua/kai/rpc/*`, `lua/kai/types/*`)
- [x] Backend package to handle listening and writing to pi process (`lua/kai/pi.lua`)
- [x] Separate buffer for the chat (`lua/kai/ui/chat.lua`)
- [x] Config page/config json file (`:KaiConfig`, `~/.config/kai/config.json`)
- [x] Virtual text for small context implementation (p99 inspired) (`lua/kai/ui/context.lua`)
- [x] Show thinking spinner (`lua/kai/ui/spinner.lua`, winbar + `💭` tail)
- [x] Extensions (passthrough `--extension`, full `extension_ui_request` dialogs)

## Setup

```lua
-- lazy.nvim
{
  dir = "~/projects/kai",
  config = function()
    require("kai").setup({
      pi_cmd = "pi",
      -- pi_args = { "--provider", "anthropic" },
      -- no_session = false,
      -- approve_project = nil, -- true => --approve, false => --no-approve
      -- extensions = { "./my-ext.ts" },
      window = { placement = "right", width = 80, input_height = 6 },
    })
  end,
}
```

`setup()` merges `defaults < ~/.config/kai/config.json < setup(opts)`.
`:KaiConfig` creates/edits the JSON file.

## Usage

- `:KaiToggle` / `:KaiOpen` / `:KaiClose` / `:KaiFocus` — chat window
- `:KaiSend [msg]` — send message; with a visual range sends selection + `@file` context
- `:KaiAbort` (`<Esc><Esc>` in input while streaming) — abort
- `:KaiNew` — `new_session`
- `:KaiCompact [instructions]` — `compact`
- `:KaiModel` / `:KaiThinking` — pickers via `get_available_models` / `get_available_thinking_levels`
- `:KaiStats` — `get_session_stats` + header virtual text
- `:KaiExport [path]` — `export_html`
- `:KaiStop` / `:KaiRestart` — backend lifecycle

Input buffer: `<CR>` (normal) or `<C-s>` (insert) sends, `<C-c>` clears,
`<C-p>`/`<C-n>` history, `q` in chat closes.

## Architecture

```
nvim ⇄ pi.lua (spawn pi --mode rpc, framer, id→callback, emit)
        ├─ rpc/serialize.lua  strict LF split, strip \r, no readline
        ├─ rpc/request.lua    command builders + new_id()
        ├─ rpc/response.lua   response matcher
        ├─ rpc/events.lua     agent/turn/message/tool/queue/compaction/retry events
        ├─ rpc/extension_ui.lua  select/confirm/input/editor + notify/status/widget/title/prefill
        └─ ui/chat.lua  chat+input splits, streaming text_delta/thinking assembly,
                        tool blocks, winbar spinner, stats refresh on agent_end
           ├─ ui/spinner.lua  uv timer → winbar frames
           └─ ui/context.lua  right-aligned stats chip + `ctx @file:range` eol hint
```

RPC notes (see `docs/rpc.md` in pi):

- Split stdout on `\n` only; strip one trailing `\r`. Never use `readline` (splits U+2028/U+2029).
- Bare `prompt` errors while streaming — `pi.prompt()` auto-uses `steeringBehavior="steer"` when busy.
- `message_update` is delta-only; assemble `text_delta`/`thinking_delta` by `contentIndex`, treat `message_end`/`agent_end.messages` as authoritative.
- `agent_settled` (not `agent_end`) means fully idle — spinner stops there.
- Extension dialogs block the agent; always reply `extension_ui_response` with matching `id`.

## Logs

`~/.local/state/nvim/kai.log` (`:lua print(require("kai.logger").get_logfile())`).
Set `log_level = vim.log.levels.DEBUG` in setup for protocol debugging.
