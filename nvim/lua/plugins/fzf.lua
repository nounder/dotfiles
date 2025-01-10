local uv = vim.uv or vim.loop
local path = require("fzf-lua.path")

local function to_relative_path(absolute_path, base_path)
  local function split_path(path)
    local parts = {}
    for part in path:gmatch("[^/]+") do
      table.insert(parts, part)
    end
    return parts
  end

  local abs_parts = split_path(absolute_path)
  local base_parts = split_path(base_path)

  -- Find common prefix length
  local common = 0
  for i = 1, math.min(#abs_parts, #base_parts) do
    if abs_parts[i] ~= base_parts[i] then
      break
    end
    common = i
  end

  -- Build relative path
  local parts = {}
  for i = common + 1, #base_parts do
    table.insert(parts, "..")
  end
  for i = common + 1, #abs_parts do
    table.insert(parts, abs_parts[i])
  end

  return #parts > 0 and table.concat(parts, "/") or "."
end

local function sim(chars)
  local keys = vim.api.nvim_replace_termcodes(chars, true, false, true)

  return function()
    vim.api.nvim_feedkeys(keys, "m", true)
  end
end

return {
  {
    "ibhagwan/fzf-lua",
    opts = {
      oldfiles = {
        cwd_only = true,
        include_current_session = true,
      },
      winopts = {
        width = 0.9,
        height = 0.9,

        preview = {
          --layout = "vertical",
          --vertical = "down:55%", -- up|down:size
          horizontal = "right:55%", -- right|left:size
        },
      },
      previewers = {
        builtin = {
          syntax_limit_b = 1024 * 100, -- 100KB
        },
      },
      files = {
        actions = {
          ["ctrl-p"] = function(selected, opts)
            local entry = path.entry_to_file(selected[1], {})

            local fullpath = entry.path
            if not path.is_absolute(fullpath) then
              fullpath = path.join({ opts.cwd or uv.cwd(), fullpath })
            end

            -- get current buffer path
            local current_buffer_path = vim.api.nvim_buf_get_name(0)
            -- make it relative to current buffer
            local rel_path = to_relative_path(fullpath, path.parent(current_buffer_path, false))

            vim.api.nvim_put({ rel_path }, "", true, true)
          end,
        },
      },
      grep = {
        -- With this change, I can sort of get the same behaviour in live_grep.
        -- ex: > enable --*/plugins/*
        -- I still find this a bit cumbersome. There's probably a better way of doing this.
        -- filter results by a glob, eg. "enabled = false -- */plugins/*"
        rg_glob = true, -- enable glob parsing
        glob_flag = "--iglob", -- case insensitive globs
        glob_separator = "%s%-%-", -- query separator pattern (lua): ' --'
      },
    },

    keys = {
      { "ff", sim("<leader>ff"), expr = true },
      { "fr", sim("<leader>fr"), expr = true },

      { "<leader>fo", "<cmd>FzfLua resume<cr>", desc = "Resume" },
      { "fo", sim("<leader>fo"), expr = true },

      { "<leader>fl", "<cmd>FzfLua grep_curbuf<cr>", desc = "Search in Current Buffer" },
      { "fl", sim("<leader>fl"), expr = true },

      { "gf", "<cmd>FzfLua lsp_finder<cr>" },
    },
  },
}
