-- plugin/markdown_gd.lua
-- Auto-opens referenced files from fenced Markdown code blocks with `gd`.

local M = {}

-- Store buffer mappings for synchronization
local sync_buffers = {}
-- Track current code buffer
local current_code_buffer = nil

-- Detect if cursor is inside a fenced block and return the fence line and boundaries.
local function get_fence_info(bufnr, lnum)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local open_idx
  for i = lnum, 1, -1 do
    if lines[i]:match("^```") then
      open_idx = i
      break
    end
  end
  if not open_idx then
    return nil
  end
  for j = open_idx + 1, #lines do
    if lines[j]:match("^```") then
      -- cursor must be after opening fence and before closing fence
      if lnum > open_idx and lnum < j then
        return {
          fence_line = lines[open_idx],
          start_line = open_idx,
          end_line = j - 1,
          content_start = open_idx + 1,
          content_end = j - 1
        }
      end
      return nil
    end
  end
  return nil
end

-- Get file extension based on language
local function get_extension_from_lang(fence)
  local lang = fence:match("^```(%w+)")
  if lang == "js" or lang == "javascript" then
    return ".js"
  elseif lang == "ts" or lang == "typescript" then
    return ".ts"
  elseif lang == "py" or lang == "python" then
    return ".py"
  elseif lang == "lua" then
    return ".lua"
  elseif lang == "html" then
    return ".html"
  elseif lang == "css" then
    return ".css"
  elseif lang == "json" then
    return ".json"
  else
    return ".txt"
  end
end

-- Extract code block content from markdown
local function get_code_block_content(md_bufnr, fence_info)
  if fence_info.content_start > fence_info.content_end then
    return {}
  end
  return vim.api.nvim_buf_get_lines(md_bufnr, fence_info.content_start - 1, fence_info.content_end, false)
end

-- Update markdown code block with buffer content
local function sync_to_markdown(code_bufnr, md_bufnr, fence_info)
  local code_lines = vim.api.nvim_buf_get_lines(code_bufnr, 0, -1, false)
  
  -- Get current markdown lines to find the closing fence
  local md_lines = vim.api.nvim_buf_get_lines(md_bufnr, 0, -1, false)
  local closing_fence_line = fence_info.start_line
  
  -- Find the current closing fence position
  for i = fence_info.start_line + 1, #md_lines do
    if md_lines[i]:match("^```$") then
      closing_fence_line = i
      break
    end
  end
  
  -- Replace content between fences
  vim.api.nvim_buf_set_lines(md_bufnr, fence_info.content_start - 1, closing_fence_line - 1, false, code_lines)
end

function M.goto_file()
  local md_bufnr = vim.api.nvim_get_current_buf()
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local fence_info = get_fence_info(md_bufnr, lnum)
  if not fence_info then
    return
  end
  local extension = get_extension_from_lang(fence_info.fence_line)
  
  -- Close existing code buffer if it exists
  if current_code_buffer and vim.api.nvim_buf_is_valid(current_code_buffer) then
    -- Clean up sync info before deleting buffer
    sync_buffers[current_code_buffer] = nil
    vim.api.nvim_buf_delete(current_code_buffer, { force = true })
  end
  
  -- Create file next to markdown with ~snippet.ext naming
  local md_bufname = vim.api.nvim_buf_get_name(md_bufnr)
  local temp_file = md_bufname .. "~snippet" .. extension
  
  -- Get the code block content
  local code_content = get_code_block_content(md_bufnr, fence_info)
  
  -- Write content to temp file
  vim.fn.writefile(code_content, temp_file)
  
  -- Open temp file in new buffer
  vim.cmd("edit " .. vim.fn.fnameescape(temp_file))
  local code_bufnr = vim.api.nvim_get_current_buf()
  
  -- Set buffer options for safety
  vim.api.nvim_buf_set_option(code_bufnr, "bufhidden", "wipe")
  
  -- Intercept save attempts and close buffer instead
  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = code_bufnr,
    callback = function(args)
      vim.api.nvim_buf_delete(args.buf, { force = true })
    end,
  })
  
  -- Track current code buffer
  current_code_buffer = code_bufnr
  
  -- Store sync information
  sync_buffers[code_bufnr] = {
    md_bufnr = md_bufnr,
    fence_info = fence_info
  }
  
  -- Set up sync autocmd for this buffer
  vim.api.nvim_create_autocmd({"TextChanged", "TextChangedI"}, {
    buffer = code_bufnr,
    callback = function()
      local sync_info = sync_buffers[code_bufnr]
      if sync_info and vim.api.nvim_buf_is_valid(sync_info.md_bufnr) then
        sync_to_markdown(code_bufnr, sync_info.md_bufnr, sync_info.fence_info)
      end
    end,
  })
  
  -- Clean up when buffer is deleted
  vim.api.nvim_create_autocmd("BufDelete", {
    buffer = code_bufnr,
    callback = function()
      -- Clean up temp file
      if vim.fn.filereadable(temp_file) == 1 then
        vim.fn.delete(temp_file)
      end
      -- Clean up tracking
      sync_buffers[code_bufnr] = nil
      if current_code_buffer == code_bufnr then
        current_code_buffer = nil
      end
    end,
  })
end

function M.setup()
  vim.api.nvim_create_autocmd("FileType", {
    pattern = "markdown",
    callback = function(args)
      vim.keymap.set("n", "gd", M.goto_file, { buffer = args.buf, desc = "Goto file from fenced block" })
    end,
  })
end

-- Auto-activate on load when placed in `plugin/`.
M.setup()

return M
