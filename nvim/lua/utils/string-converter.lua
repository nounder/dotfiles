local M = {}

function M.toggle_string_quotes()
  local filetype = vim.bo.filetype
  if not (filetype == "javascript" or filetype == "typescript" or filetype == "javascriptreact" or filetype == "typescriptreact") then
    return
  end
  
  local ts_utils = require("nvim-treesitter.ts_utils")
  local parsers = require("nvim-treesitter.parsers")
  
  if not parsers.has_parser() then
    return
  end
  
  local node = ts_utils.get_node_at_cursor()
  if not node then
    return
  end
  
  -- Find string node (could be current node or parent)
  local string_node = node
  while string_node do
    local node_type = string_node:type()
    if node_type == "string" or node_type == "template_string" then
      break
    end
    string_node = string_node:parent()
  end
  
  if not string_node or (string_node:type() ~= "string" and string_node:type() ~= "template_string") then
    return
  end
  
  -- Get string content and position
  local start_row, start_col, end_row, end_col = string_node:range()
  local lines = vim.api.nvim_buf_get_lines(0, start_row, end_row + 1, false)
  
  if #lines == 0 then
    return
  end
  
  -- Extract the full string text
  local text
  if #lines == 1 then
    text = lines[1]:sub(start_col + 1, end_col)
  else
    text = lines[1]:sub(start_col + 1)
    for i = 2, #lines - 1 do
      text = text .. "\n" .. lines[i]
    end
    text = text .. "\n" .. lines[#lines]:sub(1, end_col)
  end
  
  local new_text
  
  -- Toggle logic: ' -> " -> ` -> "
  if text:match("^'.*'$") then
    -- Single quote to double quote
    local content = text:sub(2, -2)
    new_text = '"' .. content .. '"'
  elseif text:match("^\".*\"$") then
    -- Double quote to backtick (template literal)
    local content = text:sub(2, -2)
    new_text = "`" .. content .. "`"
  elseif text:match("^`.*`$") then
    -- Backtick to double quote
    local content = text:sub(2, -2)
    new_text = '"' .. content .. '"'
  else
    return -- Not a recognized string format
  end
  
  -- Replace the text
  if #lines == 1 then
    local line = lines[1]
    local new_line = line:sub(1, start_col) .. new_text .. line:sub(end_col + 1)
    vim.api.nvim_buf_set_lines(0, start_row, start_row + 1, false, {new_line})
  else
    -- Handle multiline strings
    local first_line = lines[1]:sub(1, start_col) .. new_text
    local last_line = lines[#lines]:sub(end_col + 1)
    vim.api.nvim_buf_set_lines(0, start_row, end_row + 1, false, {first_line .. last_line})
  end
end

return M