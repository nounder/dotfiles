local M = {}

-- Map interpreter names to filetypes
local interpreter_to_ft = {
  bun = "typescript",
  node = "javascript",
  python = "python",
  python3 = "python",
  bash = "bash",
  sh = "sh",
  fish = "fish",
  ruby = "ruby",
  perl = "perl",
  php = "php",
  lua = "lua",
}

-- Detect and set filetype from shebang line
function M.detect_from_shebang()
  local bufnr = vim.api.nvim_get_current_buf()
  local filename = vim.api.nvim_buf_get_name(bufnr)

  -- Only check if there's no extension
  if filename:match("%.[^/]+$") then
    return
  end

  -- Skip if filetype is already set to something specific (not empty or generic)
  local current_ft = vim.bo[bufnr].filetype
  if current_ft ~= "" and current_ft ~= "conf" and current_ft ~= "text" then
    return
  end

  -- Read the first line
  local first_line = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1]

  if not first_line or not first_line:match("^#!") then
    return
  end

  local interpreter
  -- Check for /usr/bin/env pattern
  local env_match = first_line:match("^#!/usr/bin/env%s+(%S+)")
  if env_match then
    interpreter = env_match
  else
    -- Extract basename from direct path (e.g., #!/bin/bash -> bash)
    local path_match = first_line:match("^#!/[^%s]+/([^%s]+)")
    if path_match then
      interpreter = path_match
    end
  end

  -- Set filetype based on interpreter
  if interpreter then
    local ft = interpreter_to_ft[interpreter]
    if ft then
      vim.bo[bufnr].filetype = ft
    end
  end
end

return M
