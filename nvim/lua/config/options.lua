-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

vim.g.lazyvim_python_lsp = "pyright"

vim.opt.relativenumber = false

vim.opt.number = false

vim.opt.cursorline = false

vim.g.root_spec = { "cwd" }

vim.opt.conceallevel = 0

vim.opt.tabstop = 4
vim.opt.list = false -- Hide some invisible characters (tabs...

-- some watches cannot handle vim write behaviorr. this fixes it.
-- Source: https://github.com/oven-sh/bun/issues/8520#issuecomment-2002325950
vim.opt.backupcopy = "yes"

-- Disable horizontal scroll with mouse
vim.opt.mousescroll = "ver:1,hor:0"

-- Enable the option to require a Prettier config file
-- If no prettier config file is found, the formatter will not be used
vim.g.lazyvim_prettier_needs_config = true

vim.opt.statuscolumn = ""
