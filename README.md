# kai - NVIM Coding Agent

This is a fun little project for me to write a plugin for neovim to use pi-code inside of neovim.

> [!NOTICE]
> This is just a fun project

## Planning

- [x] RPC Protocol for pi-mono
- [ ] Backend package to handle listening and writing to pi-mono process
- [ ] Auth for Pi-Code
- [ ] Seperate buffer for the chat
- [ ] Config page/config json file
- [ ] Virtual text for small context implementation (p99 inspired)
- [ ] Show thinking spinner
- [ ] Extensions

## Notes
- use nvim_create_namespace for namespace to write virtual text
- use nvim_buf_set_extmark to add/edit virtual text
