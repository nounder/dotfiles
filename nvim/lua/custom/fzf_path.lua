-- Place this in your Neovim configuration file, e.g., ~/.config/nvim/lua/custom/import.lua

local M = {}

function M.insert_path()
  local fzf = require("fzf-lua")

  -- Define file picker options
  local opts = {
    -- You can add more fzf-lua options here if needed
    on_select = function(selected)
      -- Ensure the selected path is relative
      local current_file_dir = vim.fn.expand("%:p:h")
      local relative_path = vim.fn.fnamemodify(selected, ":~:.")

      -- Remove file extension (e.g., .ts, .tsx)
      relative_path = relative_path:gsub("%.[jt]s[xm]?$", "")

      -- Ensure the path starts with ./ or ../
      if not relative_path:match("^%.") then
        relative_path = "./" .. relative_path
      end

      -- Prepare the import statement
      -- This example imports everything; you can customize it as needed
      local import_statement = string.format("import * as Module from '%s';\n", relative_path)

      -- Insert the import statement at the cursor position
      vim.api.nvim_put({ import_statement }, "c", true, true)

      -- Optionally, move the cursor to inside the braces for customization
      -- For example, to insert specific named imports
      -- vim.api.nvim_feedkeys('i', 'n', true)
    end,
  }

  -- Launch the file picker
  fzf.files(opts)
end

return M
