-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

vim.g.lazyvim_python_lsp = "pyright"

vim.opt.relativenumber = false

vim.opt.number = false

vim.opt.cursorline = false

vim.g.root_spec = { "cwd" }

vim.opt.conceallevel = 0

vim.opt.tabstop = 2

vim.g.tabstop = 2

vim.g.ai_cmp = false

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

vim.o.statusline = "%<%#NonText#── %f %h%m%r%= %l,%c ──"

vim.opt.fillchars = {
  -- don't print end of buffer tilde (~)
  eob = " ",
  -- use vertical line in status line
  stl = "─",
}

-- More:
-- https://neovide.dev/configuration.html
if vim.g.neovide then
  vim.g.neovide_cursor_animation_length = 0
  vim.g.neovide_scroll_animation_length = 0
  vim.g.neovide_window_blurred = true

  vim.g.neovide_transparency = 0.4

  vim.g.neovide_floating_blur_amount_x = 2.0
  vim.g.neovide_floating_blur_amount_y = 2.0

  vim.g.neovide_floating_shadow = true
  vim.g.neovide_floating_z_height = 10
  vim.g.neovide_light_angle_degrees = 45
  vim.g.neovide_light_radius = 5

  vim.g.neovide_show_border = true
end
