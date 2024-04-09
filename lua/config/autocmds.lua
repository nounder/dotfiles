-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

vim.api.nvim_create_autocmd("FileType", {

  -- Don't auto-insert comment leader when using o normal cmd
  -- From: https://stackoverflow.com/questions/62459817
  command = "set formatoptions-=o",
})
