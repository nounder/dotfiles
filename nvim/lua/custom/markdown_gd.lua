-- plugin/markdown_gd.lua
-- Auto-opens referenced files from fenced Markdown code blocks with `gd`.

local M = {}

-- Store buffer mappings for synchronization
local sync_buffers = {}
-- Track current code buffer
local current_code_buffer = nil

-- Detect if cursor is inside a fenced code block using treesitter
local function get_fence_info(bufnr, lnum)
  local parser = vim.treesitter.get_parser(bufnr, "markdown")
  if not parser then
    return nil
  end

  local tree = parser:parse()[1]
  local root = tree:root()
  
  -- Convert 1-based line number to 0-based for treesitter
  local row = lnum - 1
  local col = vim.api.nvim_win_get_cursor(0)[2]
  
  -- Query for fenced code blocks
  local query = vim.treesitter.query.parse("markdown", [[
    (fenced_code_block
      (fenced_code_block_delimiter) @start
      (code_fence_content) @content
      (fenced_code_block_delimiter) @end) @block
  ]])
  
  for id, node, metadata in query:iter_captures(root, bufnr, 0, -1) do
    local capture_name = query.captures[id]
    if capture_name == "block" then
      local start_row, start_col, end_row, end_col = node:range()
      
      -- Check if cursor is within this code block
      if row >= start_row and row <= end_row then
        -- Get the fence info
        local fence_start_row = start_row + 1 -- Convert to 1-based
        local fence_end_row = end_row + 1     -- Convert to 1-based
        
        -- Get the opening fence line to extract language
        local fence_line = vim.api.nvim_buf_get_lines(bufnr, start_row, start_row + 1, false)[1]
        
        return {
          fence_line = fence_line,
          start_line = fence_start_row,
          end_line = fence_end_row,
          content_start = fence_start_row + 1,
          content_end = fence_end_row - 1
        }
      end
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

-- Extract code block content from markdown using treesitter
local function get_code_block_content(md_bufnr, fence_info)
  local parser = vim.treesitter.get_parser(md_bufnr, "markdown")
  if not parser then
    return {}
  end

  local tree = parser:parse()[1]
  local root = tree:root()
  
  -- Query for fenced code blocks content only
  local query = vim.treesitter.query.parse("markdown", [[
    (fenced_code_block
      (code_fence_content) @content) @block
  ]])
  
  for id, node, metadata in query:iter_captures(root, md_bufnr, 0, -1) do
    local capture_name = query.captures[id]
    if capture_name == "content" then
      local start_row, start_col, end_row, end_col = node:range()
      local content_start_line = start_row + 1 -- Convert to 1-based
      local content_end_line = end_row + 1     -- Convert to 1-based
      
      -- Check if this matches our fence_info range
      if content_start_line == fence_info.content_start then
        return vim.api.nvim_buf_get_lines(md_bufnr, start_row, end_row, false)
      end
    end
  end
  
  -- Fallback to original method if treesitter fails
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
  
  
  -- Use BufWritePost to sync after formatting, then save markdown
  vim.api.nvim_create_autocmd("BufWritePost", {
    buffer = code_bufnr,
    callback = function(args)
      -- Sync the formatted content back to markdown
      local sync_info = sync_buffers[args.buf]
      if sync_info and vim.api.nvim_buf_is_valid(sync_info.md_bufnr) then
        sync_to_markdown(args.buf, sync_info.md_bufnr, sync_info.fence_info)
        -- Save the markdown file
        vim.api.nvim_buf_call(sync_info.md_bufnr, function()
          vim.cmd("write")
        end)
      end
    end,
  })
  
  -- Add a manual close command instead of auto-closing
  vim.api.nvim_buf_set_keymap(code_bufnr, 'n', 'q', '<cmd>bd!<cr>', { noremap = true, silent = true })
  
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
  
  -- Clean up when buffer is about to be deleted
  vim.api.nvim_create_autocmd("BufUnload", {
    buffer = code_bufnr,
    callback = function()
      -- Clean up tracking FIRST to prevent sync during deletion
      sync_buffers[code_bufnr] = nil
      if current_code_buffer == code_bufnr then
        current_code_buffer = nil
      end
      -- Clean up temp file
      if vim.fn.filereadable(temp_file) == 1 then
        vim.fn.delete(temp_file)
      end
    end,
  })
end

-- Insert file reference at cursor position
local function insert_file_reference()
  require('snacks').picker.files({
    cwd = vim.fn.expand('%:p:h'),
    confirm = function(picker, item)
      picker:close()
      if item then
        local relative_path = vim.fn.fnamemodify(item.file, ':.')
        local filename = vim.fn.fnamemodify(item.file, ':t')
        local link_text = string.format('[%s](%s)', filename, relative_path)
        vim.api.nvim_put({ link_text }, 'c', true, true)
      end
    end
  })
end

function M.setup()
  vim.api.nvim_create_autocmd("FileType", {
    pattern = "markdown",
    callback = function(args)
      vim.keymap.set("n", "gd", M.goto_file, { buffer = args.buf, desc = "Goto file from fenced block" })
      vim.keymap.set("n", "<leader>mf", insert_file_reference, { buffer = args.buf, desc = "Insert file link" })
    end,
  })
end

-- Auto-activate on load when placed in `plugin/`.
M.setup()

return M
