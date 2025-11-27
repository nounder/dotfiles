-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

vim.api.nvim_create_autocmd("FileType", {

  -- Don't auto-insert comment leader when using o normal cmd
  -- From: https://stackoverflow.com/questions/62459817
  command = "set formatoptions-=o",
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  callback = function()
    vim.opt_local.list = false
  end,
})

vim.api.nvim_create_autocmd("BufWritePost", {
  pattern = vim.fn.expand("~/dotfiles/kitty/kitty.conf"),
  command = "silent !killall -SIGUSR1 kitty",
})

-- Detect filetype from shebang when no extension is present
local shebang_ft = require("custom.shebang_ft")

vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  callback = shebang_ft.detect_from_shebang,
})

-- Update filetype on save if not set
vim.api.nvim_create_autocmd("BufWritePost", {
  callback = shebang_ft.detect_from_shebang,
})

-- Auto-reload files when changed externally (for agent edits)
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold" }, {
  callback = function()
    if vim.fn.mode() ~= "c" then
      vim.cmd("checktime") -- Triggers autoread to actually work
    end
  end,
})
