local M = {}

-- Borrowed from snacks.picker.source.files
local commands = {
  {
    cmd = { "fd", "fdfind" },
    args = { "--type", "f", "--type", "l", "--color", "never" },
  },
  {
    cmd = { "rg" },
    args = { "--files", "--no-messages", "--color", "never" },
  },
  {
    cmd = { "find" },
    args = { ".", "-type", "f" },
    enabled = vim.fn.has("win32") == 0,
  },
}

local function get_file_cmd()
  for _, command in ipairs(commands) do
    if command.enabled ~= false then
      for _, c in ipairs(command.cmd) do
        if vim.fn.executable(c) == 1 then
          return c, vim.deepcopy(command.args)
        end
      end
    end
  end
  return nil, nil
end

function M.new(opts)
  local instance = setmetatable({
    opts = opts or {},
    items = {},
    loading = false,
    last_update = 0,
    update_interval = 10000 -- 10 seconds
  }, { __index = M })
  
  -- Pre-load files on creation
  instance:update_files()
  
  return instance
end

function M:update_files()
  if self.loading then return end
  
  local current_time = vim.uv and vim.uv.now() or vim.loop.now()
  if current_time - self.last_update < self.update_interval then
    return
  end
  
  self.loading = true
  
  vim.schedule(function()
    local cmd, args = get_file_cmd()
    if not cmd or not args then
      self.loading = false
      return
    end
    
    -- Add exclusions for .git only
    if cmd == "fd" or cmd == "fdfind" then
      vim.list_extend(args, { "-E", ".git" })
    elseif cmd == "rg" then
      vim.list_extend(args, { "-g", "!.git" })
    elseif cmd == "find" then
      vim.list_extend(args, { "-not", "-path", "*/.git/*" })
    end
    
    local items = {}
    local handle = io.popen(table.concat({cmd, unpack(args)}, " ") .. " 2>/dev/null")
    
    if handle then
      local count = 0
      local max_items = 1000
      
      for line in handle:lines() do
        if count >= max_items then break end
        
        -- Remove leading ./
        local filepath = line:gsub("^%./", "")
        if filepath ~= "" then
          table.insert(items, {
            label = filepath,
            kind = require("blink.cmp.types").CompletionItemKind.File,
            insertText = filepath,
            detail = "Project file"
          })
          count = count + 1
        end
      end
      handle:close()
    end
    
    self.items = items
    self.last_update = current_time
    self.loading = false
  end)
end

function M:get_completions(context, callback)
  local line = context.line
  local cursor_col = context.cursor[2]
  
  -- Get text before cursor
  local before_cursor = line:sub(1, cursor_col)
  
  -- Debug: uncomment to see what's being matched
  -- vim.notify("Line: '" .. line .. "', Before cursor: '" .. before_cursor .. "'", vim.log.levels.INFO)
  
  -- Check for different markdown link patterns
  local should_complete = false
  local insert_format = "plain"
  
  -- Pattern 1: @ symbol (existing)
  if before_cursor:match("@[^%s]*$") then
    should_complete = true
    insert_format = "plain"
  
  -- Pattern 2: [[ wiki-style links
  elseif before_cursor:match("%[%[[^%]]*$") then
    should_complete = true
    insert_format = "wiki"
  
  -- Pattern 3: []( markdown links  
  elseif before_cursor:match("%]%([^%)]*$") then
    should_complete = true
    insert_format = "markdown"
  end
  
  if not should_complete then
    return callback({ items = {} })
  end
  
  -- Update files if needed
  self:update_files()
  
  -- Transform items based on the detected pattern
  local items = {}
  for _, item in ipairs(self.items) do
    local new_item = vim.deepcopy(item)
    
    if insert_format == "wiki" then
      new_item.insertText = item.label
    elseif insert_format == "markdown" then
      new_item.insertText = item.label
    elseif insert_format == "bracket" then
      local filename = vim.fn.fnamemodify(item.label, ":t")
      new_item.insertText = filename .. "](" .. item.label .. ")"
    end
    
    table.insert(items, new_item)
  end
  
  callback({ items = items })
end

return M